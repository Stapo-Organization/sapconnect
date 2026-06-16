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
     * Add a QUANTITY-AWARE delivery badge next to the product name in cart.
     *
     * Reads the single source of truth (Zooboxi_Fulfillment) using the line's REAL quantity,
     * so the badge can never disagree with the cart summary or the shipping method. If the
     * requested quantity splits across tiers, each tier gets its own chip (express-first);
     * if part is unreachable, a clear "المتاح N فقط" chip is shown — never a silent 2-hour
     * promise for a quantity the nearest branch can't actually serve.
     */
    public function add_cart_item_badge(string $name, array $cartItem, string $cartKey): string
    {
        if (!is_cart() && !is_checkout()) return $name;

        // When Smart Shipments is on, items are grouped under branded shipment headers that
        // already state the tier — a per-item chip would be redundant clutter.
        if (is_cart() && class_exists('Zooboxi_Smart_Shipments') && Zooboxi_Smart_Shipments::enabled()) {
            return $name;
        }

        $session = WC()->session ?? null;
        $lat = (float) ($_COOKIE['zooboxi_lat'] ?? ($session ? $session->get('zooboxi_customer_lat') : 0));
        $lng = (float) ($_COOKIE['zooboxi_lng'] ?? ($session ? $session->get('zooboxi_customer_lng') : 0));

        if (!$lat && !$lng) return $name;

        $productId = $cartItem['product_id'] ?? 0;
        if (!$productId) return $name;

        $qty  = max(1, (int) ($cartItem['quantity'] ?? 1));
        $plan = Zooboxi_Fulfillment::resolve((int) $productId, $qty, $lat, $lng);

        // CSS class per tier (keeps existing badge styling).
        $css = [
            Zooboxi_Delivery_Engine::TYPE_EXPRESS  => 'express',
            Zooboxi_Delivery_Engine::TYPE_STANDARD => 'standard',
            Zooboxi_Delivery_Engine::TYPE_SHIPPING => 'shipping',
        ];

        $html = '';

        if (empty($plan['allocation'])) {
            $html = sprintf(
                '<span class="zooboxi-cart-badge zooboxi-cart-badge--shipping">⚠️ %s</span>',
                esc_html__('غير متاح في منطقتك', 'zooboxi')
            );
            return $name . $html;
        }

        $single = count($plan['allocation']) === 1 && $plan['shortfall'] === 0;
        foreach ($plan['allocation'] as $a) {
            $label = $single ? $a['eta'] : ((int) $a['qty'] . '× ' . $a['eta']);
            $html .= sprintf(
                '<span class="zooboxi-cart-badge zooboxi-cart-badge--%s">%s %s</span>',
                esc_attr($css[$a['tier']] ?? 'shipping'),
                esc_html($a['icon']),
                esc_html($label)
            );
        }

        if ($plan['shortfall'] > 0) {
            $html .= sprintf(
                '<span class="zooboxi-cart-badge zooboxi-cart-badge--shipping">⚠️ %s</span>',
                esc_html(sprintf(__('المتاح %d فقط', 'zooboxi'), (int) $plan['fulfillable']))
            );
        }

        return $name . $html;
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

        // Smart Shipments owns the cart-level delivery view when enabled (split baskets).
        // Avoid a second, competing summary in that case.
        if (class_exists('Zooboxi_Smart_Shipments') && Zooboxi_Smart_Shipments::enabled()) {
            return;
        }

        // Aggregate the SINGLE source of truth across every line, honestly.
        $units = ['express' => 0, 'same_day' => 0, 'shipping' => 0]; // unit counts per tier
        $tiersPresent = [];
        $anyShortfall = false;
        $slowestRank = 0;
        $rank = [
            Zooboxi_Delivery_Engine::TYPE_EXPRESS  => 1,
            Zooboxi_Delivery_Engine::TYPE_STANDARD => 2,
            Zooboxi_Delivery_Engine::TYPE_SHIPPING => 3,
        ];

        foreach ($cart->get_cart() as $item) {
            $pid = (int) ($item['product_id'] ?? 0);
            if (!$pid) continue;
            $plan = Zooboxi_Fulfillment::resolve($pid, max(1, (int) ($item['quantity'] ?? 1)), $lat, $lng);
            if ($plan['shortfall'] > 0) $anyShortfall = true;
            foreach ($plan['allocation'] as $a) {
                $units[$a['tier']] = ($units[$a['tier']] ?? 0) + (int) $a['qty'];
                $tiersPresent[$a['tier']] = true;
                $slowestRank = max($slowestRank, $rank[$a['tier']] ?? 3);
            }
        }

        $tierCount = count($tiersPresent);
        if ($tierCount === 0 && !$anyShortfall) return; // nothing resolvable, no location signal

        $etaFor = [
            Zooboxi_Delivery_Engine::TYPE_EXPRESS  => __('خلال ساعتين', 'zooboxi'),
            Zooboxi_Delivery_Engine::TYPE_STANDARD => __('خلال 24 ساعة', 'zooboxi'),
            Zooboxi_Delivery_Engine::TYPE_SHIPPING => __('4-5 أيام عمل', 'zooboxi'),
        ];
        $slowestType = array_search($slowestRank, $rank, true) ?: Zooboxi_Delivery_Engine::TYPE_SHIPPING;

        // Single honest headline.
        if ($tierCount === 1 && !$anyShortfall) {
            $only = array_key_first($tiersPresent);
            $css = ['express' => 'express', 'same_day' => 'standard', 'shipping' => 'shipping'][$only] ?? 'shipping';
            $icon = $only === Zooboxi_Delivery_Engine::TYPE_EXPRESS ? '🎉' : ($only === Zooboxi_Delivery_Engine::TYPE_STANDARD ? '🚚' : '📦');
            $text = sprintf(__('سيصلك طلبك %s', 'zooboxi'), $etaFor[$only]);
        } else {
            $css = 'mixed';
            $icon = 'ℹ️';
            $text = sprintf(__('سيصلك طلبك على دفعات حسب السرعة — يكتمل خلال %s', 'zooboxi'), $etaFor[$slowestType]);
        }

        // Per-tier unit breakdown chips.
        $chips = [];
        if (!empty($units['express']))  $chips[] = ['express',  '⚡', sprintf(__('%d خلال ساعتين', 'zooboxi'), $units['express'])];
        if (!empty($units['same_day'])) $chips[] = ['standard', '🚚', sprintf(__('%d خلال 24 ساعة', 'zooboxi'), $units['same_day'])];
        if (!empty($units['shipping'])) $chips[] = ['shipping', '📦', sprintf(__('%d خلال 4-5 أيام', 'zooboxi'), $units['shipping'])];

        ?>
        <div class="zooboxi-cart-delivery-summary zooboxi-cart-delivery-summary--<?php echo esc_attr($css); ?>">
            <div class="zooboxi-cart-delivery-summary__icon"><?php echo $icon; ?></div>
            <div class="zooboxi-cart-delivery-summary__content">
                <div class="zooboxi-cart-delivery-summary__text"><?php echo esc_html($text); ?></div>
                <?php if (count($chips) > 1): ?>
                <div class="zooboxi-cart-delivery-summary__breakdown">
                    <?php foreach ($chips as $c): ?>
                    <span class="zooboxi-cart-delivery-count zooboxi-cart-delivery-count--<?php echo esc_attr($c[0]); ?>">
                        <?php echo esc_html($c[1] . ' ' . $c[2]); ?>
                    </span>
                    <?php endforeach; ?>
                </div>
                <?php endif; ?>
                <?php if ($anyShortfall): ?>
                <div class="zooboxi-cart-delivery-summary__note">
                    <?php echo esc_html__('عدّلنا بعض الكميات إلى المتاح فعلياً في منطقتك.', 'zooboxi'); ?>
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
