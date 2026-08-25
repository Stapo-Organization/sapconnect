<?php
/**
 * Sync Engine — pulls products, stock, and prices from sapconnect API
 * and pushes orders from WooCommerce to sapconnect.
 */
class Zooboxi_Sync_Engine
{
    private string $api_base;
    private string $api_token;
    private const MAX_RETRIES = 3;

    public function __construct()
    {
        $this->api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $this->api_token = get_option('zooboxi_api_token', '');
    }

    /* ── Products ──────────────────────────────────── */

    public function sync_products(): array
    {
        $logId = Zooboxi_Logger::start('products');
        $page  = 1;
        $synced = $failed = 0;

        try {
            do {
                $response = $this->api_get("/products?page={$page}&per_page=50");
                $products = $response['data'] ?? [];

                foreach ($products as $product) {
                    try {
                        $this->upsert_product($product);
                        $synced++;
                    } catch (\Exception $e) {
                        $failed++;
                        error_log("Zooboxi Product Sync Error [{$product['item_code']}]: {$e->getMessage()}");
                    }
                }

                $page++;
            } while (count($products) >= 50);

            Zooboxi_Logger::complete($logId, $synced, $failed);
        } catch (\Exception $e) {
            Zooboxi_Logger::fail($logId, $e->getMessage());
        }

        return ['synced' => $synced, 'failed' => $failed];
    }

    /* ── Stock ─────────────────────────────────────── */

    public function sync_stock(): array
    {
        $logId = Zooboxi_Logger::start('stock');
        $updated = 0;

        try {
            $response = $this->api_get('/stock');
            $items = $response['data'] ?? [];

            foreach ($items as $item) {
                $productId = $this->find_product_by_item_code($item['item_code'] ?? '');
                if (!$productId) continue;

                $warehouseStocks = $item['warehouses'] ?? [];
                Zooboxi_Stock_Manager::update_stock($productId, $warehouseStocks);
                $updated++;
            }

            Zooboxi_Logger::complete($logId, $updated, 0, count($items));
        } catch (\Exception $e) {
            Zooboxi_Logger::fail($logId, $e->getMessage());
        }

        return ['updated' => $updated];
    }

    /* ── Prices ────────────────────────────────────── */

    public function sync_prices(): array
    {
        $logId = Zooboxi_Logger::start('prices');
        $updated = 0;

        try {
            $response = $this->api_get('/prices');
            $items = $response['data'] ?? [];
            $priceList = (int) get_option('zooboxi_default_price_list', 1);

            foreach ($items as $item) {
                $productId = $this->find_product_by_item_code($item['item_code'] ?? '');
                if (!$productId) continue;

                $prices = $item['prices'] ?? [];
                $retail = $this->extract_price($prices, $priceList);

                if ($retail !== null && $retail > 0) {
                    update_post_meta($productId, '_regular_price', (string) $retail);
                    // Respect an existing clearance sale price; otherwise current price = regular.
                    $sale = get_post_meta($productId, '_sale_price', true);
                    $current = ($sale !== '' && (float) $sale > 0 && (float) $sale < $retail) ? (string) $sale : (string) $retail;
                    update_post_meta($productId, '_price', $current);
                }

                // Store all price lists for future use
                update_post_meta($productId, '_zooboxi_price_lists', wp_json_encode($prices));
                $updated++;
            }

            Zooboxi_Logger::complete($logId, $updated, 0, count($items));
        } catch (\Exception $e) {
            Zooboxi_Logger::fail($logId, $e->getMessage());
        }

        return ['updated' => $updated];
    }

    /* ── Warehouses ────────────────────────────────── */

    public function sync_warehouses(): array
    {
        $logId = Zooboxi_Logger::start('warehouses');
        $synced = 0;

        try {
            $response = $this->api_get('/warehouses');
            $warehouses = $response['data'] ?? [];

            foreach ($warehouses as $wh) {
                Zooboxi_Warehouse_Manager::upsert($wh);
                $synced++;
            }

            Zooboxi_Logger::complete($logId, $synced, 0, count($warehouses));
        } catch (\Exception $e) {
            Zooboxi_Logger::fail($logId, $e->getMessage());
        }

        return ['synced' => $synced];
    }

    /* ── Push Order to sapconnect ──────────────────── */

    public function push_order(int $orderId): bool
    {
        $order = wc_get_order($orderId);
        if (!$order) return false;

        $logId = Zooboxi_Logger::start('orders', 'push');

        try {
            $payload = $this->build_order_payload($order);
            $response = $this->api_post('/orders', $payload);

            if (!empty($response['order_id'])) {
                $order->update_meta_data('_zooboxi_synced', true);
                $order->update_meta_data('_zooboxi_synced_at', current_time('mysql'));
                $order->update_meta_data('_zooboxi_sap_order_id', $response['order_id']);
                $order->save();
                Zooboxi_Logger::complete($logId, 1);
                return true;
            }

            Zooboxi_Logger::fail($logId, 'No order_id in response');
            return false;
        } catch (\Exception $e) {
            Zooboxi_Logger::fail($logId, $e->getMessage());
            // Schedule retry
            wp_schedule_single_event(time() + 300, 'zooboxi_retry_order_push', [$orderId]);
            return false;
        }
    }

    /**
     * Mirror an order's CURRENT delivery + payment status to sapconnect.
     *
     * push_order() was a one-shot at creation time, so every later transition
     * (paid, preparing, جاهز للتسليم, delivered, cancelled) never reached the backend.
     * This closes that gap. Deliberately short-timeout and non-retrying: it runs inside
     * woocommerce_order_status_changed, which fires on the storefront and in wp-admin —
     * a slow backend must never stall a status change. Failures are logged, not raised.
     */
    public function push_order_status(int $orderId, string $newStatus): bool
    {
        try {
            $order = wc_get_order($orderId);
            if (!$order || $this->api_token === '') {
                return false;
            }
            // Only orders the backend already knows about are worth updating.
            if (!$order->get_meta('_zooboxi_synced')) {
                return false;
            }

            // The mirror's delivery_status vocabulary is the STAFF prep pipeline
            // (pending/preparing/ready_for_pickup/out_for_delivery/delivered/cancelled)
            // — Woo statuses must not stomp it. Only a real cancellation crosses over;
            // everything else updates payment state only.
            $woo = preg_replace('/^wc-/', '', $newStatus);
            $body = [
                'woo_order_id'   => $orderId,
                'payment_status' => $order->is_paid() ? 'paid' : 'pending',
                'paid_at'        => $order->get_date_paid() ? $order->get_date_paid()->date('Y-m-d H:i:s') : null,
                'total'          => (float) $order->get_total(),
            ];
            if (in_array($woo, ['cancelled', 'refunded'], true)) {
                $body['delivery_status'] = 'cancelled';
            }

            $response = wp_remote_request($this->api_base . '/orders/' . $orderId . '/status', [
                'method'  => 'PUT',
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->api_token,
                    'Accept'        => 'application/json',
                    'Content-Type'  => 'application/json',
                ],
                'body'    => wp_json_encode($body),
                'timeout' => 8,
            ]);

            if (is_wp_error($response)) {
                error_log('[Zooboxi] push_order_status failed for #' . $orderId . ': ' . $response->get_error_message());
                return false;
            }

            $code = (int) wp_remote_retrieve_response_code($response);
            if ($code < 200 || $code >= 300) {
                error_log('[Zooboxi] push_order_status #' . $orderId . ' returned HTTP ' . $code);
                return false;
            }

            $order->update_meta_data('_zooboxi_status_pushed_at', current_time('mysql'));
            $order->save();
            return true;
        } catch (\Throwable $e) {
            error_log('[Zooboxi] push_order_status threw for #' . $orderId . ': ' . $e->getMessage());
            return false;
        }
    }

    /* ── Private Helpers ──────────────────────────── */

    /**
     * Extract the price for a given SAP price list from the raw prices payload.
     *
     * SAP / sapconnect emit a LIST of objects with CAPITAL keys:
     *   [{"PriceList":1,"Price":140,...}, {"PriceList":2,"Price":190,...}]
     * The old code did `$prices[$priceList]` (array POSITION, so list #1 = the 2nd
     * element = PriceList 2) and read `['price']` (lowercase, which never exists),
     * silently zeroing every price. This matches by PriceList VALUE and reads `Price`
     * with a lowercase fallback. Also tolerates payloads keyed by price-list number.
     *
     * @return float|null  the price, or null if none found
     */
    private function extract_price(array $prices, int $priceList): ?float
    {
        if (empty($prices)) return null;

        $readPrice = static function ($row): ?float {
            if (!is_array($row)) return null;
            $p = $row['Price'] ?? $row['price'] ?? null;
            return $p === null ? null : (float) $p;
        };

        // 1) Match by PriceList value (capital, lowercase, or the array key as a fallback).
        foreach ($prices as $key => $row) {
            if (!is_array($row)) continue;
            $pl = $row['PriceList'] ?? $row['priceList'] ?? $row['price_list'] ?? null;
            if ($pl === null && is_numeric($key)) $pl = (int) $key;
            if ($pl !== null && (int) $pl === $priceList) {
                $p = $readPrice($row);
                if ($p !== null) return $p;
            }
        }

        // 2) Fallback: first row that carries a positive price.
        foreach ($prices as $row) {
            $p = $readPrice($row);
            if ($p !== null && $p > 0) return $p;
        }

        return null;
    }

    private function upsert_product(array $data): void
    {
        $itemCode = $data['item_code'] ?? '';
        if (empty($itemCode)) throw new \RuntimeException('Missing item_code');

        // Find product by _zooboxi_item_code meta (NOT by SKU - SKU uses barcode)
        $existingId = $this->find_product_by_item_code($itemCode);

        if ($existingId) {
            // ─── EXISTING PRODUCT: Update with ZID rich data ───
            $product = wc_get_product($existingId);
            if (!$product) return;

            // Update price (match by PriceList value + capital 'Price' key)
            $price = $this->extract_price($data['prices'] ?? [], (int) get_option('zooboxi_default_price_list', 1));
            if ($price !== null && $price > 0) {
                $product->set_regular_price((string) $price);
            }

            // Update name from ZID (prefer Arabic)
            $nameAr = $data['name_ar'] ?? '';
            $nameEn = $data['name_en'] ?? '';
            if (!empty($nameAr)) {
                $product->set_name($nameAr);
            }

            // Update descriptions from ZID
            $descAr = $data['description_ar'] ?? '';
            $descEn = $data['description_en'] ?? '';
            if (!empty($descAr)) {
                $product->set_description($descAr);
            } elseif (!empty($descEn)) {
                $product->set_description($descEn);
            }

            $shortDescAr = $data['short_description_ar'] ?? '';
            $shortDescEn = $data['short_description_en'] ?? '';
            if (!empty($shortDescAr)) {
                $product->set_short_description($shortDescAr);
            } elseif (!empty($shortDescEn)) {
                $product->set_short_description($shortDescEn);
            }

            // Update weight
            if (!empty($data['weight'])) {
                $product->set_weight((string) $data['weight']);
            }

            // Update SKU (barcode) if available and not set
            if (!empty($data['barcode'])) {
                try {
                    $product->set_sku($data['barcode']);
                } catch (\Exception $e) {
                    // SKU already exists — skip
                }
            }

            // Ensure stock management
            $product->set_manage_stock(true);
            $product->set_stock_status('instock');
            $product->save();

            // Update SAP metadata
            update_post_meta($existingId, '_zooboxi_sap_name', $data['item_name'] ?? '');
            update_post_meta($existingId, '_zooboxi_sap_foreign_name', $data['foreign_name'] ?? '');
            update_post_meta($existingId, '_zooboxi_brand_code', $data['brand_code'] ?? '');
            update_post_meta($existingId, '_zooboxi_barcode', $data['barcode'] ?? '');
            update_post_meta($existingId, '_zooboxi_uom', $data['uom'] ?? '');
            update_post_meta($existingId, '_zooboxi_price_lists', wp_json_encode($data['prices'] ?? []));
            update_post_meta($existingId, '_zooboxi_last_sync', current_time('mysql'));

            // Store ZID keywords for SEO
            if (!empty($data['keywords'])) {
                update_post_meta($existingId, '_zooboxi_keywords', $data['keywords']);
            }

            // Update categories from ZID
            $catAr = $data['categories_ar'] ?? '';
            if (!empty($catAr)) {
                $catParts = array_filter(array_map('trim', explode(',', $catAr)));
                if (!empty($catParts)) {
                    $termIds = [];
                    foreach ($catParts as $catPath) {
                        // Handle nested categories like "قطط > طعام جاف"
                        $segments = array_filter(array_map('trim', explode('>', $catPath)));
                        $parentId = 0;
                        foreach ($segments as $seg) {
                            $term = term_exists($seg, 'product_cat', $parentId ?: null);
                            if (!$term) {
                                $term = wp_insert_term($seg, 'product_cat', $parentId ? ['parent' => $parentId] : []);
                            }
                            if (!is_wp_error($term)) {
                                $parentId = is_array($term) ? (int) $term['term_id'] : (int) $term;
                                $termIds[] = $parentId;
                            }
                        }
                    }
                    if (!empty($termIds)) {
                        wp_set_object_terms($existingId, $termIds, 'product_cat');
                    }
                }
            }

            // Assign brand as category too
            if (!empty($data['brand_name'])) {
                wp_set_object_terms($existingId, $data['brand_name'], 'product_cat', true);
            }

        } else {
            // ─── NEW PRODUCT: Create with ZID + SAP data ───
            $product = new \WC_Product_Simple();

            $nameAr = $data['name_ar'] ?? '';
            $nameEn = $data['name_en'] ?? '';
            $name = !empty($nameAr) ? $nameAr : (!empty($nameEn) ? $nameEn : ($data['item_name'] ?? $itemCode));

            $product->set_props([
                'name'          => $name,
                'regular_price' => (string) ($this->extract_price($data['prices'] ?? [], (int) get_option('zooboxi_default_price_list', 1)) ?? ''),
                'manage_stock'  => true,
                'stock_status'  => 'instock',
                'catalog_visibility' => 'visible',
            ]);

            // Set barcode as SKU if available
            if (!empty($data['barcode'])) {
                try {
                    $product->set_sku($data['barcode']);
                } catch (\Exception $e) {
                    // SKU already exists — skip
                }
            }

            // Description from ZID
            $descAr = $data['description_ar'] ?? '';
            $descEn = $data['description_en'] ?? '';
            if (!empty($descAr)) {
                $product->set_description($descAr);
            } elseif (!empty($descEn)) {
                $product->set_description($descEn);
            }

            $shortDescAr = $data['short_description_ar'] ?? '';
            $shortDescEn = $data['short_description_en'] ?? '';
            if (!empty($shortDescAr)) {
                $product->set_short_description($shortDescAr);
            } elseif (!empty($shortDescEn) || !empty($data['foreign_name'])) {
                $product->set_short_description($shortDescEn ?: $data['foreign_name']);
            }

            // Weight
            if (!empty($data['weight'])) {
                $product->set_weight((string) $data['weight']);
            }

            // Image from holeno.com
            $imageUrl = $data['image_url'] ?? '';
            if ($imageUrl) {
                $product->add_meta_data('_zooboxi_image_url', $imageUrl, true);
            }

            $productId = $product->save();

            // Store SAP identifiers
            update_post_meta($productId, '_zooboxi_item_code', $itemCode);
            update_post_meta($productId, '_zooboxi_sap_name', $data['item_name'] ?? '');
            update_post_meta($productId, '_zooboxi_sap_foreign_name', $data['foreign_name'] ?? '');
            update_post_meta($productId, '_zooboxi_brand_code', $data['brand_code'] ?? '');
            update_post_meta($productId, '_zooboxi_barcode', $data['barcode'] ?? '');
            update_post_meta($productId, '_zooboxi_uom', $data['uom'] ?? '');
            update_post_meta($productId, '_zooboxi_price_lists', wp_json_encode($data['prices'] ?? []));
            update_post_meta($productId, '_zooboxi_last_sync', current_time('mysql'));

            // Keywords
            if (!empty($data['keywords'])) {
                update_post_meta($productId, '_zooboxi_keywords', $data['keywords']);
            }

            // Assign categories from ZID
            $catAr = $data['categories_ar'] ?? '';
            if (!empty($catAr)) {
                $catParts = array_filter(array_map('trim', explode(',', $catAr)));
                foreach ($catParts as $catPath) {
                    $segments = array_filter(array_map('trim', explode('>', $catPath)));
                    $parentId = 0;
                    foreach ($segments as $seg) {
                        $term = term_exists($seg, 'product_cat', $parentId ?: null);
                        if (!$term) {
                            $term = wp_insert_term($seg, 'product_cat', $parentId ? ['parent' => $parentId] : []);
                        }
                        if (!is_wp_error($term)) {
                            $parentId = is_array($term) ? (int) $term['term_id'] : (int) $term;
                        }
                    }
                }
            }
            if (!empty($data['brand_name'])) {
                wp_set_object_terms($productId, $data['brand_name'], 'product_cat', true);
            }
        }
    }

    /**
     * Find a WC product ID by its _zooboxi_item_code meta value.
     */
    private function find_product_by_item_code(string $itemCode): int
    {
        global $wpdb;
        $id = $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta} 
             WHERE meta_key = '_zooboxi_item_code' AND meta_value = %s 
             LIMIT 1",
            $itemCode
        ));
        return (int) $id;
    }

    private function build_order_payload(\WC_Order $order): array
    {
        $items = [];
        foreach ($order->get_items() as $item) {
            $product = $item->get_product();
            $items[] = [
                'item_code'   => $product ? $product->get_sku() : '',
                'item_name'   => $item->get_name(),
                'quantity'    => $item->get_quantity(),
                'unit_price'  => (float) ($item->get_total() / max($item->get_quantity(), 1)),
                'total_price' => (float) $item->get_total(),
            ];
        }

        return [
            'woo_order_id'     => $order->get_id(),
            'woo_order_number' => $order->get_order_number(),
            'delivery_type'    => $order->get_meta('_zooboxi_delivery_type') ?: 'shipping',
            'warehouse_code'   => $order->get_meta('_zooboxi_warehouse') ?: '',
            'customer' => [
                'name'      => $order->get_formatted_billing_full_name(),
                'phone'     => $order->get_billing_phone(),
                'email'     => $order->get_billing_email(),
                // Precise checkout-map pin first; fall back to billing field, then session.
                'latitude'  => (float) ($order->get_meta('_zooboxi_checkout_lat')
                    ?: $order->get_meta('_billing_zooboxi_lat')
                    ?: $order->get_meta('_zooboxi_lat')),
                'longitude' => (float) ($order->get_meta('_zooboxi_checkout_lng')
                    ?: $order->get_meta('_billing_zooboxi_lng')
                    ?: $order->get_meta('_zooboxi_lng')),
                'city'      => $order->get_shipping_city() ?: $order->get_billing_city(),
                'address'   => $order->get_shipping_address_1() ?: $order->get_billing_address_1(),
            ],
            'items' => $items,
            'payment' => [
                'method' => $order->get_payment_method(),
                'status' => $order->is_paid() ? 'paid' : 'pending',
            ],
            'totals' => [
                'subtotal'     => (float) $order->get_subtotal(),
                'delivery_fee' => (float) $order->get_shipping_total(),
                'tax'          => (float) $order->get_total_tax(),
                'total'        => (float) $order->get_total(),
            ],
        ];
    }

    private function api_get(string $endpoint): array
    {
        return $this->api_request('GET', $endpoint);
    }

    private function api_post(string $endpoint, array $data): array
    {
        return $this->api_request('POST', $endpoint, $data);
    }

    private function api_request(string $method, string $endpoint, array $body = []): array
    {
        $url = $this->api_base . $endpoint;
        $args = [
            'headers' => [
                'Authorization' => 'Bearer ' . $this->api_token,
                'Accept'        => 'application/json',
                'Content-Type'  => 'application/json',
            ],
            'timeout' => 30,
        ];

        $attempts = 0;
        while ($attempts < self::MAX_RETRIES) {
            $response = ($method === 'POST')
                ? wp_remote_post($url, array_merge($args, ['body' => wp_json_encode($body)]))
                : wp_remote_get($url, $args);

            if (!is_wp_error($response)) {
                $code = wp_remote_retrieve_response_code($response);
                $decoded = json_decode(wp_remote_retrieve_body($response), true);

                if ($code >= 200 && $code < 300) {
                    return $decoded ?: [];
                }

                throw new \RuntimeException("API {$method} {$endpoint} returned {$code}: " . ($decoded['message'] ?? ''));
            }

            $attempts++;
            if ($attempts < self::MAX_RETRIES) {
                sleep($attempts * 2);
            }
        }

        throw new \RuntimeException("API {$method} {$endpoint} failed after " . self::MAX_RETRIES . " attempts: " . $response->get_error_message());
    }
}
