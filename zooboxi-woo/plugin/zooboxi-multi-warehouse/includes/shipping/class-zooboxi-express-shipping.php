<?php
/**
 * Express Shipping — delivery within 2 hours from nearest express-enabled warehouse.
 * Checks GPS coordinates → finds express warehouses → verifies ALL cart items have stock.
 */
class Zooboxi_Express_Shipping extends WC_Shipping_Method
{
    public function __construct($instance_id = 0)
    {
        $this->id                 = 'zooboxi_express';
        $this->instance_id        = absint($instance_id);
        $this->method_title       = __('توصيل سريع Zooboxi', 'zooboxi');
        $this->method_description = __('توصيل خلال ساعتين من أقرب مستودع — يتطلب توفر جميع المنتجات + ساعات العمل', 'zooboxi');
        $this->supports           = ['shipping-zones', 'instance-settings'];
        $this->enabled            = 'yes';
        $this->title              = __('🚀 توصيل سريع (خلال ساعتين)', 'zooboxi');
        $this->init();
    }

    public function init(): void
    {
        $this->init_settings();
    }

    /**
     * Direct check — does NOT rely on session cart_analysis.
     * Always checks express warehouses and stock from DB.
     */
    public function calculate_shipping($package = []): void
    {
        // Tier gate: once the cart is split into per-tier shipments, express is the ONLY option
        // for an express shipment (no "change the delivery speed" choice — fast stays fast).
        $tier = is_array($package) ? ($package['zooboxi_tier'] ?? null) : null;
        if (null !== $tier && 'express' !== $tier) {
            return;
        }

        // 1. Get customer GPS from session → cookies
        $lat = 0.0;
        $lng = 0.0;

        if (function_exists('WC') && WC()->session) {
            $lat = (float) WC()->session->get('zooboxi_customer_lat');
            $lng = (float) WC()->session->get('zooboxi_customer_lng');
        }
        if (!$lat && !empty($_COOKIE['zooboxi_lat'])) $lat = (float) $_COOKIE['zooboxi_lat'];
        if (!$lng && !empty($_COOKIE['zooboxi_lng'])) $lng = (float) $_COOKIE['zooboxi_lng'];

        if (!$lat || !$lng) return;

        // 2. Find express warehouses near the customer (checks zone + working hours)
        $expressWarehouses = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
        if (empty($expressWarehouses)) return;

        // 3. For each express warehouse (nearest first), check if ALL items are in stock
        foreach ($expressWarehouses as $ew) {
            $whCode = $ew['warehouse']['warehouse_code'];

            $allAvailable = true;
            foreach ($package['contents'] as $item) {
                // Use parent product ID (warehouse stock is stored on parent, not variation)
                $productId = $item['product_id'];

                // Read warehouse stock directly from postmeta (bypasses WC filters)
                $stockMeta = get_post_meta($productId, '_zooboxi_warehouse_stock', true);

                // Fallback: if variation_id exists and parent has no meta, this is already the right ID
                if (empty($stockMeta) && !empty($item['variation_id'])) {
                    // product_id should already be parent, but double-check
                    $parentId = wp_get_post_parent_id($item['variation_id']);
                    if ($parentId && $parentId !== $productId) {
                        $stockMeta = get_post_meta($parentId, '_zooboxi_warehouse_stock', true);
                    }
                }

                if (empty($stockMeta)) {
                    $allAvailable = false;
                    break;
                }

                $stockData = is_string($stockMeta) ? json_decode($stockMeta, true) : $stockMeta;
                if (!is_array($stockData)) {
                    $allAvailable = false;
                    break;
                }

                $needQty = (int) ($item['quantity'] ?? 1);
                $found = false;
                foreach ($stockData as $ws) {
                    // Express requires the branch to hold the FULL requested quantity.
                    if (($ws['warehouse_code'] ?? '') === $whCode && ((int) ($ws['in_stock'] ?? 0)) >= $needQty) {
                        $found = true;
                        break;
                    }
                }

                if (!$found) {
                    $allAvailable = false;
                    break;
                }
            }

            if (!$allAvailable) continue; // Try next express warehouse

            // 4. All items available — add express rate
            $fee = (float) apply_filters('zooboxi_express_fee', (float) get_option('zooboxi_express_fee', 15));
            $freeMin = (float) apply_filters('zooboxi_free_shipping_min', (float) get_option('zooboxi_free_shipping_min', 200));
            // Order-level free shipping: if the WHOLE order qualifies, every shipment (incl. express)
            // is free — so splitting into baskets never adds a surprise charge.
            $orderTotal = (function_exists('WC') && WC()->cart) ? (float) WC()->cart->get_subtotal() : (float) ($package['contents_cost'] ?? 0);
            if ($orderTotal >= $freeMin) $fee = 0;

            $this->add_rate([
                'id'        => $this->id,
                'label'     => $this->title,
                'cost'      => $fee,
                'meta_data' => [
                    'warehouse_code' => $whCode,
                    'delivery_type'  => 'express',
                    'estimated_time' => '2 hours',
                ],
            ]);
            return; // Only show one express option (nearest eligible warehouse)
        }
    }
}
