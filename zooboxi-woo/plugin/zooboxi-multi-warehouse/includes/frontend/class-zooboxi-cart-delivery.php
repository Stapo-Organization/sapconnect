<?php
/**
 * Cart Delivery — shows per-item delivery badges and mixed delivery summary in cart.
 * Option A: slowest item dictates overall delivery, no split shipments.
 */
class Zooboxi_Cart_Delivery
{
    public function __construct()
    {
        // Per-item delivery badge in cart
        add_filter('woocommerce_cart_item_name', [$this, 'add_cart_item_badge'], 10, 3);

        // Delivery summary banner before cart totals
        add_action('woocommerce_before_cart_totals', [$this, 'render_delivery_summary'], 5);

        // Store cart analysis in session BEFORE shipping is calculated
        // Priority 5 ensures it runs before WC_Cart->calculate_shipping()
        add_action('woocommerce_before_calculate_totals', [$this, 'analyze_cart_on_load'], 5);
    }

    /**
     * Add delivery badge next to product name in cart.
     */
    public function add_cart_item_badge(string $name, array $cartItem, string $cartKey): string
    {
        if (!is_cart() && !is_checkout()) return $name;

        $session = WC()->session ?? null;
        $lat = (float) ($_COOKIE['zooboxi_lat'] ?? ($session ? $session->get('zooboxi_customer_lat') : 0));
        $lng = (float) ($_COOKIE['zooboxi_lng'] ?? ($session ? $session->get('zooboxi_customer_lng') : 0));

        if (!$lat && !$lng) return $name;

        $productId = $cartItem['product_id'] ?? 0;
        if (!$productId) return $name;

        $delivery = Zooboxi_Delivery_Engine::detect_product_delivery($productId, $lat, $lng);
        $type = $delivery['type'] ?? 'shipping';

        $badges = [
            'express'  => ['icon' => '⚡', 'label' => __('خلال ساعتين', 'zooboxi'), 'css' => 'express'],
            'same_day' => ['icon' => '📦', 'label' => __('خلال 24 ساعة', 'zooboxi'), 'css' => 'standard'],
            'shipping' => ['icon' => '🚚', 'label' => __('4-5 أيام', 'zooboxi'), 'css' => 'shipping'],
        ];

        $badge = $badges[$type] ?? $badges['shipping'];

        $badgeHtml = sprintf(
            '<span class="zooboxi-cart-badge zooboxi-cart-badge--%s">%s %s</span>',
            esc_attr($badge['css']),
            esc_html($badge['icon']),
            esc_html($badge['label'])
        );

        return $name . $badgeHtml;
    }

    /**
     * Render delivery summary banner above cart totals.
     */
    public function render_delivery_summary(): void
    {
        $session = WC()->session ?? null;
        $lat = (float) ($_COOKIE['zooboxi_lat'] ?? ($session ? $session->get('zooboxi_customer_lat') : 0));
        $lng = (float) ($_COOKIE['zooboxi_lng'] ?? ($session ? $session->get('zooboxi_customer_lng') : 0));

        if (!$lat && !$lng) return;

        $cart = WC()->cart;
        if (!$cart || $cart->is_empty()) return;

        // Build cart items array for analysis
        $cartItems = [];
        foreach ($cart->get_cart() as $key => $item) {
            $cartItems[$key] = [
                'product_id' => $item['product_id'],
                'quantity'   => $item['quantity'],
            ];
        }

        $analysis = Zooboxi_Delivery_Engine::analyze_cart_delivery($cartItems, $lat, $lng);

        $expressCount = count($analysis['express_items']);
        $standardCount = count($analysis['standard_items']);
        $shippingCount = count($analysis['shipping_items']);
        $totalCount = $expressCount + $standardCount + $shippingCount;

        // Determine icon and CSS class
        if ($analysis['all_express'] && $expressCount > 0) {
            $css = 'express';
            $icon = '🎉';
        } elseif ($expressCount > 0) {
            $css = 'mixed';
            $icon = 'ℹ️';
        } elseif ($standardCount > 0 && $shippingCount === 0) {
            $css = 'standard';
            $icon = '📦';
        } else {
            $css = 'shipping';
            $icon = '🚚';
        }

        ?>
        <div class="zooboxi-cart-delivery-summary zooboxi-cart-delivery-summary--<?php echo esc_attr($css); ?>">
            <div class="zooboxi-cart-delivery-summary__icon"><?php echo $icon; ?></div>
            <div class="zooboxi-cart-delivery-summary__content">
                <div class="zooboxi-cart-delivery-summary__text">
                    <?php echo esc_html($analysis['summary']); ?>
                </div>
                <?php if ($expressCount > 0 && !$analysis['all_express']): ?>
                <div class="zooboxi-cart-delivery-summary__breakdown">
                    <span class="zooboxi-cart-delivery-count zooboxi-cart-delivery-count--express">
                        ⚡ <?php echo sprintf(esc_html__('%d سريع', 'zooboxi'), $expressCount); ?>
                    </span>
                    <?php if ($standardCount > 0): ?>
                    <span class="zooboxi-cart-delivery-count zooboxi-cart-delivery-count--standard">
                        📦 <?php echo sprintf(esc_html__('%d عادي', 'zooboxi'), $standardCount); ?>
                    </span>
                    <?php endif; ?>
                    <?php if ($shippingCount > 0): ?>
                    <span class="zooboxi-cart-delivery-count zooboxi-cart-delivery-count--shipping">
                        🚚 <?php echo sprintf(esc_html__('%d شحن', 'zooboxi'), $shippingCount); ?>
                    </span>
                    <?php endif; ?>
                </div>
                <?php endif; ?>
            </div>
        </div>
        <?php
    }

    /**
     * Analyze cart before totals are calculated and store results for shipping.
     * Runs via woocommerce_before_calculate_totals (before calculate_shipping).
     */
    public function analyze_cart_on_load($cart = null): void
    {
        // Prevent duplicate runs in the same request
        static $done = false;
        if ($done) return;

        $session = WC()->session ?? null;
        if (!$session) return;

        $lat = (float) ($session->get('zooboxi_customer_lat') ?: ($_COOKIE['zooboxi_lat'] ?? 0));
        $lng = (float) ($session->get('zooboxi_customer_lng') ?: ($_COOKIE['zooboxi_lng'] ?? 0));

        if (!$lat && !$lng) return;

        if (!$cart) $cart = WC()->cart;
        if (!$cart || $cart->is_empty()) return;

        $cartItems = [];
        foreach ($cart->get_cart() as $key => $item) {
            $cartItems[$key] = [
                'product_id' => $item['product_id'],
                'quantity'   => $item['quantity'],
            ];
        }

        $analysis = Zooboxi_Delivery_Engine::analyze_cart_delivery($cartItems, $lat, $lng);
        $session->set('zooboxi_cart_analysis', $analysis);
        $session->set('zooboxi_delivery_type', $analysis['overall_type']);

        if ($analysis['express_warehouse']) {
            $session->set('zooboxi_warehouse_code', $analysis['express_warehouse']);
        }

        $done = true;
    }
}
