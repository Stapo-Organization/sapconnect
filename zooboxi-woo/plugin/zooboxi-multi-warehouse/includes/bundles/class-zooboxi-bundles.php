<?php
/**
 * «حزم زوبوكسي» — owner-approved bundles materialised as REAL WC products.
 *
 * The backend suggests bundles nightly; the owner approves in the app; this
 * module pulls the approved definitions hourly and turns each into a simple
 * WC product: regular price = the components' retail sum, sale price = the
 * bundle price, per-warehouse stock = the minimum a warehouse can build —
 * written in the SAME `_zooboxi_warehouse_stock` shape the SAP mirror uses,
 * so the fulfillment resolver, cart badges and smart shipments treat a
 * bundle exactly like any other product, promises included.
 *
 * Channel safety: unit prices never appear discounted anywhere; the bundle
 * carries one combined price. Order payloads pushed to the backend expand a
 * bundle line into its component lines so branch picking sees real items.
 */
class Zooboxi_Bundles
{
    private const FEED_OPT = 'zooboxi_bundles_synced_at';
    public const CAT_SLUG = 'zb-bundles';
    public const CAT_NAME = 'البكجات';

    /** Never advertise more than this many of one bundle per warehouse. */
    private const MAX_PER_WAREHOUSE = 20;

    /** Skip materialising when store prices drifted this far from the snapshot. */
    private const PRICE_DRIFT = 0.05;

    private string $api_base;
    private string $api_token;

    public function __construct()
    {
        $this->api_base  = rtrim(get_option('zooboxi_api_url', 'https://sapapi.muntajat.sa/api/woo'), '/');
        $this->api_token = get_option('zooboxi_api_token', '');

        add_action('zooboxi_sync_bundles', [$this, 'sync']);
        if (!wp_next_scheduled('zooboxi_sync_bundles')) {
            wp_schedule_event(time() + 600, 'hourly', 'zooboxi_sync_bundles');
        }

        // Recompute bundle stock right after every SAP stock mirror pass
        // (the mirror handler runs at priority 10 on the same event).
        add_action('zooboxi_sync_stock', [$this, 'recompute_stock'], 20);

        // Manual "sync now" (admin).
        add_action('wp_ajax_zooboxi_sync_bundles', [$this, 'ajax_sync']);

        // The component strip's styles, on a bundle's own page only.
        add_action('wp_head', [$this, 'print_card_styles']);

        // Readable «محتويات البكج» on order lines (admin, e-mails, receipts).
        add_action('woocommerce_new_order', [$this, 'annotate_order'], 20, 1);
        add_action('woocommerce_checkout_order_processed', [$this, 'annotate_order'], 20, 1);
    }

    /* ══════════════════════════════════════════════════════════════
       SYNC — pull definitions, materialise, retire, report back
       ══════════════════════════════════════════════════════════════ */

    public function sync(): array
    {
        $res = wp_remote_get($this->api_base . '/bundles/active', [
            'headers' => ['Authorization' => 'Bearer ' . $this->api_token, 'Accept' => 'application/json'],
            'timeout' => 30,
        ]);
        if (is_wp_error($res) || wp_remote_retrieve_response_code($res) !== 200) {
            return ['error' => is_wp_error($res) ? $res->get_error_message() : 'http ' . wp_remote_retrieve_response_code($res)];
        }
        $body = json_decode(wp_remote_retrieve_body($res), true);
        if (!is_array($body)) {
            return ['error' => 'bad body'];
        }

        $made = 0;
        $failed = 0;
        foreach ((array) ($body['data'] ?? []) as $def) {
            $out = $this->materialise($def);
            $out ? $made++ : $failed++;
        }

        $retired = 0;
        foreach ((array) ($body['retired'] ?? []) as $row) {
            if ($this->retire((int) ($row['id'] ?? 0), (int) ($row['wc_product_id'] ?? 0))) {
                $retired++;
            }
        }

        $this->recompute_stock();
        update_option(self::FEED_OPT, current_time('mysql'), false);

        return ['materialised' => $made, 'failed' => $failed, 'retired' => $retired];
    }

    public function ajax_sync(): void
    {
        if (!current_user_can('manage_woocommerce')) {
            wp_die('', '', ['response' => 403]);
        }
        wp_send_json($this->sync());
    }

    /**
     * One definition → one live WC product. Idempotent: matched by
     * `_zb_bundle_id`, updated in place on every pull.
     */
    private function materialise(array $def): bool
    {
        $bundleId = (int) ($def['id'] ?? 0);
        if ($bundleId <= 0 || empty($def['items']) || (float) ($def['bundle_price'] ?? 0) <= 0) {
            return false;
        }

        // Resolve every component to a live store product. Store products are
        // often VARIABLE (حبة/كرتون variations) — the bundle speaks in pieces,
        // so a variable component prices at its single-piece variation.
        $components = [];
        $storeSum = 0.0;
        foreach ((array) $def['items'] as $item) {
            $pid = $this->product_by_item_code((string) ($item['item_code'] ?? ''));
            $product = $pid ? wc_get_product($pid) : null;
            if (!$product || $product->get_status() !== 'publish') {
                return $this->report($bundleId, null, 'failed', 'component missing: ' . ($item['item_code'] ?? '?'));
            }
            $qty = max(1, (int) ($item['qty'] ?? 1));
            [$unitPrice, $variationId] = $this->piece_price($product, (string) ($item['barcode'] ?? ''));
            if ($unitPrice <= 0) {
                return $this->report($bundleId, null, 'failed', 'no piece price: ' . ($item['item_code'] ?? '?'));
            }
            $storeSum += $qty * $unitPrice;
            $component = [
                'item_code'    => (string) $item['item_code'],
                'barcode'      => (string) ($item['barcode'] ?? $product->get_sku()),
                'name'         => (string) ($item['name'] ?? $product->get_name()),
                'qty'          => $qty,
                'role'         => (string) ($item['role'] ?? 'member'),
                'product_id'   => $pid,
                'variation_id' => $variationId,
                'unit_retail'  => $unitPrice,
            ];
            $component['weight_kg'] = $this->piece_kg($component);
            $components[] = $component;
        }

        // The approved thing is the SAVINGS PERCENTAGE, not the absolute
        // number: the backend prices from SAP's list 1, the store sells at
        // its own (higher, VAT-inclusive) retail. Reprice on the store's own
        // sum with the approved percentage — that can only sit FURTHER above
        // the cost floor. A store sum that dropped BELOW the snapshot is the
        // dangerous direction (the floor was proven against the snapshot), so
        // that one is refused and the nightly run re-suggests with fresh data.
        $snapshotSum = (float) ($def['sum_retail'] ?? 0);
        if ($snapshotSum <= 0 || $storeSum <= 0
            || $storeSum < $snapshotSum * (1 - self::PRICE_DRIFT)) {
            return $this->report($bundleId, null, 'failed',
                sprintf('price drift down: snapshot %.2f vs store %.2f', $snapshotSum, $storeSum));
        }
        $savingsPct = max(0.0, min(45.0, (float) ($def['savings_pct'] ?? 0)));
        $salePrice = round($storeSum * (1 - $savingsPct / 100), 2);

        $existing = (int) ($def['wc_product_id'] ?? 0) ?: $this->product_by_bundle_id($bundleId);

        $postarr = [
            'post_title'   => (string) $def['name_ar'],
            'post_excerpt' => (string) ($def['subtitle_ar'] ?? ''),
            'post_content' => $this->description_html($components),
            'post_status'  => 'publish',
            'post_type'    => 'product',
        ];
        if ($existing) {
            $postarr['ID'] = $existing;
            $productId = wp_update_post($postarr, true);
        } else {
            $productId = wp_insert_post($postarr, true);
        }
        if (is_wp_error($productId) || !$productId) {
            return $this->report($bundleId, null, 'failed', 'wp_insert_post failed');
        }

        wp_set_object_terms($productId, 'simple', 'product_type');
        wp_set_object_terms($productId, [$this->category_id()], 'product_cat');

        update_post_meta($productId, '_zb_bundle_id', $bundleId);
        // wp_slash because update_post_meta STRIPS slashes — without it the
        // \uXXXX escapes lose their backslashes and Arabic names come out as
        // gibberish. Unescaped unicode keeps the stored JSON human-readable.
        update_post_meta($productId, '_zb_bundle_components',
            wp_slash(wp_json_encode($components, JSON_UNESCAPED_UNICODE)));
        update_post_meta($productId, '_zb_bundle_free_label', (string) ($def['free_label'] ?? ''));
        update_post_meta($productId, '_zb_bundle_class', (string) ($def['stock_class'] ?? 'central'));
        update_post_meta($productId, '_zb_bundle_template', (string) ($def['template'] ?? ''));
        update_post_meta($productId, '_zb_bundle_species', (string) ($def['species'] ?? 'mixed'));
        update_post_meta($productId, '_regular_price', (string) round($storeSum, 2));
        update_post_meta($productId, '_sale_price', (string) $salePrice);
        update_post_meta($productId, '_price', (string) $salePrice);
        update_post_meta($productId, '_virtual', 'no');
        update_post_meta($productId, '_sold_individually', 'no');
        update_post_meta($productId, '_visibility', 'visible');

        if (!$existing) {
            // SKU: a namespace no barcode or SAP code can collide with.
            update_post_meta($productId, '_sku', 'BNDL-' . $bundleId);
        }

        // Image: the composed collage card from the backend when it exists
        // (re-sideloaded whenever its ?v= changes); else the anchor's photo.
        $cardUrl = (string) ($def['image_url'] ?? '');
        if ($cardUrl !== '') {
            $this->set_card_image($productId, $cardUrl);
        }
        if (!get_post_thumbnail_id($productId)) {
            foreach ($components as $c) {
                if ($c['role'] === 'anchor') {
                    $thumb = get_post_thumbnail_id($c['product_id']);
                    if ($thumb) {
                        set_post_thumbnail($productId, $thumb);
                    }
                    break;
                }
            }
        }

        $this->stock_for($productId, $components);
        wc_delete_product_transients($productId);

        return $this->report($bundleId, (int) $productId, 'live', '', [
            'store_sum' => round($storeSum, 2),
            'store_price' => $salePrice,
        ]);
    }

    /**
     * Sideload the composed card once per version and set it as the product
     * image. `_zb_bundle_img_src` remembers the exact URL (the backend
     * cache-busts with ?v=mtime), so an unchanged card costs nothing.
     */
    private function set_card_image(int $productId, string $url): void
    {
        if (get_post_meta($productId, '_zb_bundle_img_src', true) === $url
            && get_post_thumbnail_id($productId)) {
            return;
        }

        require_once ABSPATH . 'wp-admin/includes/media.php';
        require_once ABSPATH . 'wp-admin/includes/file.php';
        require_once ABSPATH . 'wp-admin/includes/image.php';

        $attachmentId = media_sideload_image($url, $productId, null, 'id');
        if (is_wp_error($attachmentId)) {
            return; // keep whatever image the product has
        }

        $old = get_post_thumbnail_id($productId);
        set_post_thumbnail($productId, (int) $attachmentId);
        update_post_meta($productId, '_zb_bundle_img_src', $url);

        // Drop the previous card attachment (only ones we sideloaded ourselves).
        if ($old && $old !== (int) $attachmentId
            && (int) get_post_field('post_parent', $old) === $productId) {
            wp_delete_attachment($old, true);
        }
    }

    /**
     * The single-PIECE price of a component (and the variation carrying it).
     * Simple product → its own regular price. Variable → the variation whose
     * units factor is 1 (else the one whose SKU is the piece barcode, else
     * the smallest pack), at that variation's regular price.
     *
     * @return array{0:float,1:int} [unit_price, variation_id (0 = simple)]
     */
    private function piece_price(\WC_Product $product, string $barcode): array
    {
        if (!$product->is_type('variable')) {
            return [(float) $product->get_regular_price(), 0];
        }

        $best = null; // [units, price, id]
        foreach ($product->get_children() as $childId) {
            $child = wc_get_product($childId);
            if (!$child) {
                continue;
            }
            $units = class_exists('Zooboxi_Units') ? Zooboxi_Units::for_id($childId) : 1;
            $price = (float) $child->get_regular_price();
            if ($price <= 0) {
                continue;
            }
            if ($units === 1 || ($barcode !== '' && $child->get_sku() === $barcode)) {
                return [$price, $childId];
            }
            if ($best === null || $units < $best[0]) {
                $best = [$units, $price, $childId];
            }
        }

        // Only multi-piece packs exist: price one piece as pack ÷ units.
        return $best === null ? [0.0, 0] : [round($best[1] / max(1, $best[0]), 2), $best[2]];
    }

    private function retire(int $bundleId, int $wcProductId): bool
    {
        $productId = $wcProductId ?: $this->product_by_bundle_id($bundleId);
        if ($productId && get_post($productId)) {
            wp_update_post(['ID' => $productId, 'post_status' => 'draft']);
            update_post_meta($productId, '_stock', 0);
            update_post_meta($productId, '_stock_status', 'outofstock');
            wc_delete_product_transients($productId);
        }
        return $this->report($bundleId, null, 'retired');
    }

    private function report(int $bundleId, ?int $wcProductId, string $status, string $error = '', array $extra = []): bool
    {
        $payload = array_merge(['status' => $status], $extra);
        if ($wcProductId) {
            $payload['wc_product_id'] = $wcProductId;
        }
        if ($error !== '') {
            $payload['error'] = $error;
        }
        wp_remote_post($this->api_base . '/bundles/' . $bundleId . '/materialized', [
            'headers' => ['Authorization' => 'Bearer ' . $this->api_token, 'Content-Type' => 'application/json'],
            'body'    => wp_json_encode($payload),
            'timeout' => 15,
        ]);
        return $status === 'live' || $status === 'retired';
    }

    /* ══════════════════════════════════════════════════════════════
       STOCK — a bundle's stock is the min its components allow
       ══════════════════════════════════════════════════════════════ */

    /** Recompute every live bundle. Cheap: a handful of bundles, meta reads only. */
    public function recompute_stock(): void
    {
        foreach ($this->live_bundle_ids() as $productId) {
            $raw = get_post_meta($productId, '_zb_bundle_components', true);
            $components = is_string($raw) ? json_decode($raw, true) : $raw;
            if (is_array($components) && $components !== []) {
                $this->stock_for($productId, $components);
            }
        }
    }

    /**
     * Per warehouse: floor(min over components of stock/qty), capped. The
     * result is written through Zooboxi_Stock_Manager so `_stock`,
     * `_stock_status` and the per-warehouse JSON stay in the canonical shape.
     */
    private function stock_for(int $productId, array $components): void
    {
        $perWarehouse = null;

        foreach ($components as $c) {
            $rows = Zooboxi_Stock_Manager::get_warehouse_stock((int) ($c['product_id'] ?? 0));
            $qty = max(1, (int) ($c['qty'] ?? 1));

            $mine = [];
            foreach ($rows as $row) {
                $code = (string) ($row['warehouse_code'] ?? '');
                if ($code === '') {
                    continue;
                }
                $mine[$code] = (int) floor(((float) ($row['in_stock'] ?? 0)) / $qty);
            }

            if ($perWarehouse === null) {
                $perWarehouse = $mine;
                continue;
            }
            // Intersect: a warehouse missing ANY component builds zero bundles.
            foreach ($perWarehouse as $code => $units) {
                $perWarehouse[$code] = min($units, $mine[$code] ?? 0);
            }
        }

        $stocks = [];
        foreach ((array) $perWarehouse as $code => $units) {
            $stocks[] = [
                'warehouse_code' => $code,
                'in_stock'       => min(max(0, $units), self::MAX_PER_WAREHOUSE),
            ];
        }

        // 'all': a bundle owns none of its stock — every warehouse figure here is
        // DERIVED from the components (whoever wrote those, SAP or ShipGo), so this
        // writer legitimately rebuilds the whole array.
        Zooboxi_Stock_Manager::update_stock($productId, $stocks, 'all');
    }

    /* ══════════════════════════════════════════════════════════════
       ORDERS — expand + annotate
       ══════════════════════════════════════════════════════════════ */

    /**
     * Expand bundle lines in the backend order payload into component lines,
     * each priced at its share of what the customer actually paid — so branch
     * picking sees real SAP items with real photos.
     *
     * @param array<int,array> $items  built payload rows, index-aligned with…
     * @param \WC_Order        $order  …the order's items.
     */
    public static function expand_payload_items(array $items, \WC_Order $order): array
    {
        $out = [];
        $i = 0;
        foreach ($order->get_items() as $orderItem) {
            $row = $items[$i++] ?? null;
            if ($row === null) {
                continue;
            }

            $product = $orderItem->get_product();
            $raw = $product ? get_post_meta($product->get_id(), '_zb_bundle_components', true) : '';
            $components = is_string($raw) && $raw !== '' ? json_decode($raw, true) : null;
            if (!is_array($components) || $components === []) {
                $out[] = $row;
                continue;
            }

            $bundles = max(1, (int) $orderItem->get_quantity());
            $paid = (float) $orderItem->get_total();
            $sum = 0.0;
            foreach ($components as $c) {
                $sum += ((float) ($c['unit_retail'] ?? 0) ?: 1.0) * max(1, (int) ($c['qty'] ?? 1));
            }

            foreach ($components as $c) {
                $qty = max(1, (int) ($c['qty'] ?? 1)) * $bundles;
                $lineRetail = ((float) ($c['unit_retail'] ?? 0) ?: 1.0) * max(1, (int) ($c['qty'] ?? 1));
                $share = $sum > 0 ? $paid * ($lineRetail / $sum) : 0.0;
                $out[] = [
                    'item_code'   => (string) ($c['barcode'] ?? ''),
                    'item_name'   => sprintf('%s (ضمن %s)', $c['name'] ?? '', wp_strip_all_tags($orderItem->get_name())),
                    'quantity'    => $qty,
                    'unit_price'  => round($qty > 0 ? $share / $qty : 0, 4),
                    'total_price' => round($share, 4),
                ];
            }
        }

        return $out;
    }

    /** Attach a readable component list to bundle order lines (idempotent). */
    public function annotate_order($orderId): void
    {
        $order = wc_get_order($orderId);
        if (!$order) {
            return;
        }
        foreach ($order->get_items() as $item) {
            $product = $item->get_product();
            if (!$product) {
                continue;
            }
            $raw = get_post_meta($product->get_id(), '_zb_bundle_components', true);
            $components = is_string($raw) && $raw !== '' ? json_decode($raw, true) : null;
            if (!is_array($components) || $components === [] || $item->get_meta('محتويات البكج')) {
                continue;
            }
            $lines = array_map(
                static fn(array $c): string => sprintf(
                    '%d × %s%s',
                    max(1, (int) ($c['qty'] ?? 1)),
                    (string) ($c['name'] ?? ''),
                    ($c['role'] ?? '') === 'gift' ? ' (هدية)' : ''
                ),
                $components
            );
            $item->add_meta_data('محتويات البكج', implode("\n", $lines), true);
            $item->save();
        }
    }

    /* ══════════════════════════════════════════════════════════════
       RANKING — لكل عميل حزمته أولاً
       ══════════════════════════════════════════════════════════════ */

    /**
     * Live bundle product ids, best-first for this viewer.
     *
     * Signals: the pet's species (owner of cats sees cat bundles first), the
     * food gauge (a bundle of a due staple jumps to the top), express
     * reachability for the caller's location, then savings depth.
     *
     * @param string $shelf The storefront being browsed ('express' | 'all'),
     *                      '' for the website, which is not split into tabs.
     *                      A bundle the shelf's own warehouse cannot build is
     *                      DROPPED, not merely ranked lower: the إكسبريس tab
     *                      showing a bundle only the main warehouse holds is a
     *                      product the basket then has to refuse.
     *
     * @return int[]
     */
    public static function ranked_ids(int $userId, float $lat = 0.0, float $lng = 0.0, int $limit = 24, string $shelf = ''): array
    {
        $ids = self::instance_live_ids();
        if ($ids === []) {
            return [];
        }

        $species = [];
        if ($userId > 0 && class_exists('Zooboxi_Loyalty_Pets')) {
            $species = Zooboxi_Loyalty_Pets::species_of($userId);
        }
        $dueIds = [];
        if ($userId > 0 && class_exists('Zooboxi_Loyalty_Supply')) {
            $dueIds = Zooboxi_Loyalty_Supply::on_time_ids($userId);
        }

        // The same predicate the add-to-cart guard uses, so the shelf can
        // never show what the basket would turn away.
        $scoped = $shelf !== ''
            && class_exists('Zooboxi_Cart_Shelf')
            && Zooboxi_Cart_Shelf::valid($shelf);

        $scored = [];
        foreach ($ids as $pid) {
            $product = wc_get_product($pid);
            if (!$product || !$product->is_in_stock()) {
                continue;
            }
            if ($scoped && !Zooboxi_Cart_Shelf::fits($pid, $shelf)) {
                continue;
            }

            $score = 0.0;

            $bSpecies = (string) get_post_meta($pid, '_zb_bundle_species', true);
            if ($species !== []) {
                if (in_array($bSpecies, $species, true)) {
                    $score += 40;
                } elseif ($bSpecies !== 'mixed' && $bSpecies !== '') {
                    $score -= 30; // dog bundles sink for a cat household
                }
            }

            // The customer's own staple is about to run out → its bundle leads.
            if ($dueIds !== []) {
                $raw = get_post_meta($pid, '_zb_bundle_components', true);
                $components = is_string($raw) ? json_decode($raw, true) : null;
                foreach ((array) $components as $c) {
                    if (in_array((int) ($c['product_id'] ?? 0), $dueIds, true)) {
                        $score += 60;
                        break;
                    }
                }
            }

            // Express bundles the caller can actually reach outrank shipping.
            if ($lat && $lng && class_exists('Zooboxi_Fulfillment')) {
                $plan = Zooboxi_Fulfillment::resolve($pid, 1, $lat, $lng);
                if ((int) ($plan['reachable_total'] ?? 0) > 0) {
                    $fastest = (string) ($plan['fastest'] ?? '');
                    if ($fastest === Zooboxi_Delivery_Engine::TYPE_EXPRESS) {
                        $score += 20;
                    } elseif ($fastest === Zooboxi_Delivery_Engine::TYPE_STANDARD) {
                        $score += 10;
                    }
                }
            }

            // Savings depth as the base note.
            $regular = (float) $product->get_regular_price();
            $sale = (float) $product->get_sale_price();
            if ($regular > 0 && $sale > 0 && $sale < $regular) {
                $score += (1 - $sale / $regular) * 25;
            }

            $scored[$pid] = $score;
        }

        arsort($scored);
        return array_slice(array_keys($scored), 0, $limit);
    }

    /* ══════════════════════════════════════════════════════════════
       LOOKUPS
       ══════════════════════════════════════════════════════════════ */

    /** @return int[] published products carrying a bundle id. */
    private static function instance_live_ids(): array
    {
        global $wpdb;
        $rows = $wpdb->get_col(
            "SELECT pm.post_id FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_zb_bundle_id' AND p.post_status = 'publish' AND p.post_type = 'product'"
        );
        return array_map('intval', (array) $rows);
    }

    private function live_bundle_ids(): array
    {
        return self::instance_live_ids();
    }

    private function product_by_item_code(string $itemCode): int
    {
        if ($itemCode === '') {
            return 0;
        }
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta}
             WHERE meta_key = '_zooboxi_item_code' AND meta_value = %s LIMIT 1",
            $itemCode
        ));
    }

    private function product_by_bundle_id(int $bundleId): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            "SELECT post_id FROM {$wpdb->postmeta}
             WHERE meta_key = '_zb_bundle_id' AND meta_value = %d LIMIT 1",
            $bundleId
        ));
    }

    /** The «البكجات» category, created on first use. */
    public function category_id(): int
    {
        $term = get_term_by('slug', self::CAT_SLUG, 'product_cat');
        if ($term instanceof \WP_Term) {
            return (int) $term->term_id;
        }
        $made = wp_insert_term(self::CAT_NAME, 'product_cat', ['slug' => self::CAT_SLUG]);
        return is_wp_error($made) ? 0 : (int) $made['term_id'];
    }

    private function description_html(array $components): string
    {
        $rows = '';
        $pieces = 0;
        $totalKg = 0.0;
        $weighed = true;

        foreach ($components as $c) {
            $qty = max(1, (int) ($c['qty'] ?? 1));
            $pieces += $qty;

            $kg = isset($c['weight_kg']) && is_numeric($c['weight_kg']) ? (float) $c['weight_kg'] : null;
            if ($kg === null) {
                $weighed = false;
            } else {
                $totalKg += $kg * $qty;
            }

            // The weight is the detail a bundle buyer actually weighs up: the
            // piece size, and — when there is more than one — what the line
            // adds up to. Silence beats a guess when the size is unknown.
            $detail = '';
            if ($kg !== null) {
                $detail = ' — ' . self::format_weight($kg);
                if ($qty > 1) {
                    $detail .= ' للحبة · ' . self::format_weight($kg * $qty) . ' إجمالاً';
                }
            }

            $rows .= sprintf(
                '<li>%d × %s%s%s</li>',
                $qty,
                esc_html((string) ($c['name'] ?? '')),
                esc_html($detail),
                ($c['role'] ?? '') === 'gift' ? ' <strong>(هدية)</strong>' : ''
            );
        }

        $summary = 'إجمالي البكج: ' . self::pieces_phrase($pieces);
        if ($weighed && $totalKg > 0) {
            $summary .= ' · ' . self::format_weight($totalKg);
        }

        // Two renderings of one list. The cards are what a browser shows —
        // photo, name, count, size, each linking to the product itself. The
        // <ul> under them is the same list in plain text, which is what a
        // reader, a search engine, and the app's tag-stripping description
        // fall back to; the app draws its own cards from the DTO instead.
        return $this->cards_html($components)
            . '<ul class="zb-bundle-list">' . $rows . '</ul>'
            . '<p><strong>' . esc_html($summary) . '</strong></p>';
    }

    /** The horizontal, tappable component strip shown on the store. */
    private function cards_html(array $components): string
    {
        $cards = '';
        foreach ($components as $c) {
            $pid = (int) ($c['product_id'] ?? 0);
            $product = $pid ? wc_get_product($pid) : null;
            if (! $product instanceof \WC_Product) {
                continue;
            }

            $qty = max(1, (int) ($c['qty'] ?? 1));
            $kg = isset($c['weight_kg']) && is_numeric($c['weight_kg']) ? (float) $c['weight_kg'] : null;
            $image = $product->get_image('woocommerce_thumbnail', ['class' => 'zb-bc__img', 'loading' => 'lazy']);
            $isGift = ($c['role'] ?? '') === 'gift';

            $meta = 'الكمية في البكج: ' . $qty;
            if ($kg !== null) {
                $meta .= ' · ' . self::format_weight($kg);
            }

            $cards .= '<a class="zb-bc" href="' . esc_url(get_permalink($pid)) . '">'
                . '<span class="zb-bc__media">' . $image
                . ($isGift ? '<span class="zb-bc__gift">هدية</span>' : '')
                . '<span class="zb-bc__qty">×' . $qty . '</span>'
                . '</span>'
                . '<span class="zb-bc__name">' . esc_html((string) ($c['name'] ?? '')) . '</span>'
                . '<span class="zb-bc__meta">' . esc_html($meta) . '</span>'
                . '</a>';
        }

        if ($cards === '') {
            return '<p><strong>محتويات البكج</strong></p>';
        }

        return '<p><strong>محتويات البكج</strong></p>'
            . '<div class="zb-bundle-cards">' . $cards . '</div>';
    }

    /**
     * The component strip's styles, printed in the head of a bundle's own
     * page. They cannot ride inside the description: post content is saved
     * through wp_kses_post, which drops a <style> tag on the floor.
     */
    public function print_card_styles(): void
    {
        if (!is_singular('product') || !get_post_meta(get_the_ID(), '_zb_bundle_id', true)) {
            return;
        }
        echo '<style>
.zb-bundle-cards{display:flex;gap:12px;overflow-x:auto;padding:4px 2px 12px;scroll-snap-type:x proximity;-webkit-overflow-scrolling:touch}
.zb-bundle-cards::-webkit-scrollbar{height:6px}
.zb-bundle-cards::-webkit-scrollbar-thumb{background:#d9d5cb;border-radius:999px}
.zb-bc{flex:0 0 150px;scroll-snap-align:start;display:flex;flex-direction:column;gap:6px;padding:10px;
  border:1px solid #e7e2d6;border-radius:16px;background:#fff;text-decoration:none;color:inherit;
  transition:box-shadow .18s ease,transform .18s ease}
.zb-bc:hover{box-shadow:0 8px 20px rgba(0,0,0,.09);transform:translateY(-2px)}
.zb-bc__media{position:relative;display:block;background:#f6f4ef;border-radius:12px;overflow:hidden}
.zb-bc__media .zb-bc__img{display:block;width:100%;height:auto;aspect-ratio:1/1;object-fit:contain}
.zb-bc__qty{position:absolute;inset-inline-start:6px;bottom:6px;background:#275f5e;color:#fff;
  font-size:12px;font-weight:800;border-radius:999px;padding:2px 8px}
.zb-bc__gift{position:absolute;inset-inline-end:6px;top:6px;background:#d46856;color:#fff;
  font-size:11px;font-weight:800;border-radius:999px;padding:2px 8px}
.zb-bc__name{font-size:13px;font-weight:700;line-height:1.4;display:-webkit-box;-webkit-line-clamp:2;
  -webkit-box-orient:vertical;overflow:hidden}
.zb-bc__meta{font-size:11.5px;color:#6b7472}
.zb-bundle-list{margin-top:4px}
@media (prefers-color-scheme:dark){
  .zb-bc{background:#1f2626;border-color:#2e3838}
  .zb-bc__media{background:#161b1b}
  .zb-bc__meta{color:#9fada9}
}
</style>';
    }

    /* ══════════════════════════════════════════════════════════════
       WEIGHTS
       ══════════════════════════════════════════════════════════════ */

    /** A pet-food piece weighs somewhere between 5 grams and 30 kilos. */
    private static function plausible_kg($kg): bool
    {
        return is_numeric($kg) && $kg >= 0.005 && $kg <= 30;
    }

    /**
     * One piece's weight in kg, or null when nothing trustworthy says.
     *
     * The store's own `_weight` column cannot be believed on its own: an 85 g
     * can is recorded as "85.000" in a kilogram field and a 1.75 kg bag as
     * "0.00175". So the name and the pack parser — which read the size the
     * brand actually prints — are asked first, and `_weight` is accepted only
     * when it lands in a plausible range (or is plainly grams above it).
     */
    private function piece_kg(array $component): ?float
    {
        $variationId = (int) ($component['variation_id'] ?? 0);
        $parent = wc_get_product((int) ($component['product_id'] ?? 0));
        $variation = $variationId ? wc_get_product($variationId) : null;

        if (class_exists('Zooboxi_Loyalty_Supply')) {
            $target = $variation instanceof \WC_Product ? $variation : $parent;
            if ($target instanceof \WC_Product) {
                $kg = Zooboxi_Loyalty_Supply::pack_kg($target, $parent instanceof \WC_Product ? $parent : null);
                if (self::plausible_kg($kg)) {
                    return (float) $kg;
                }
            }
            $kg = Zooboxi_Loyalty_Supply::parse_kg((string) ($component['name'] ?? ''));
            if (self::plausible_kg($kg)) {
                return (float) $kg;
            }
        }

        $raw = $variation instanceof \WC_Product
            ? $variation->get_weight()
            : ($parent instanceof \WC_Product ? $parent->get_weight() : '');
        if ($raw !== '' && is_numeric($raw)) {
            $kg = (float) $raw;
            if (self::plausible_kg($kg)) {
                return $kg;
            }
            // Above 30 kg in a kilogram field, the number is grams.
            if ($kg > 30 && self::plausible_kg($kg / 1000)) {
                return $kg / 1000;
            }
        }

        return null;
    }

    /**
     * The counted noun, in Arabic rather than in English wearing Arabic
     * words: one is قطعة, two is قطعتان, three-to-ten take the broken plural
     * قطع, and everything above ten goes back to the singular.
     */
    public static function pieces_phrase(int $n): string
    {
        if ($n === 1) {
            return 'قطعة واحدة';
        }
        if ($n === 2) {
            return 'قطعتان';
        }
        if ($n >= 3 && $n <= 10) {
            return $n . ' قطع';
        }
        return $n . ' قطعة';
    }

    /** "85 غ" under a kilo, "7.5 كجم" above it. */
    public static function format_weight(float $kg): string
    {
        if ($kg < 1) {
            return round($kg * 1000) . ' غ';
        }
        $value = number_format($kg, 2, '.', '');
        if (str_contains($value, '.')) {
            $value = rtrim(rtrim($value, '0'), '.');
        }
        return $value . ' كجم';
    }
}
