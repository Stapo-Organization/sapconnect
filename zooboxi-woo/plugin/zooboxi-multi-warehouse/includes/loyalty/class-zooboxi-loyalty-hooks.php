<?php
/**
 * Zooboxi_Loyalty_Hooks — where the program touches WooCommerce.
 *
 * EVERY handler in this file is total: it re-checks that the module is on, that the
 * tables exist, that WooCommerce is loaded and that the order belongs to a real
 * customer, and it swallows its own exceptions. A loyalty bug must never be able to
 * stop an order from being placed, paid, or delivered — the program is a passenger on
 * the checkout, never a gate in front of it.
 *
 * The moment that matters is `completed`, not `processing`: paws are earned and prizes
 * become real only once the customer actually has the goods.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Loyalty_Hooks
{
    private static bool $registered = false;

    public static function register(): void
    {
        if (self::$registered) {
            return;
        }
        self::$registered = true;

        // ── Order lifecycle ──
        // Priority 20: after Zooboxi_Plugin::on_order_created (10) has stamped the
        // delivery metadata and pushed the order to sapconnect.
        add_action('woocommerce_order_status_completed', [__CLASS__, 'on_completed'], 20, 2);
        add_action('woocommerce_order_status_cancelled', [__CLASS__, 'on_reversed'], 20, 2);
        add_action('woocommerce_order_status_refunded', [__CLASS__, 'on_reversed'], 20, 2);
        add_action('woocommerce_order_status_changed', [__CLASS__, 'on_status_changed'], 25, 4);

        // ── Checkout ──
        add_action('woocommerce_checkout_order_processed', [__CLASS__, 'on_order_processed'], 20, 3);
        add_action('woocommerce_checkout_create_order_line_item', [__CLASS__, 'on_create_line_item'], 20, 4);

        // ── Cart ──
        add_action('woocommerce_before_calculate_totals', [__CLASS__, 'enforce_gift_lines'], 5);
        add_action('woocommerce_cart_item_removed', [__CLASS__, 'on_cart_item_removed'], 10, 2);
        add_filter('woocommerce_update_cart_validation', [__CLASS__, 'block_gift_quantity'], 10, 4);
        add_filter('woocommerce_cart_item_quantity', [__CLASS__, 'gift_quantity_html'], 10, 3);
        add_filter('woocommerce_cart_item_price', [__CLASS__, 'gift_price_html'], 10, 3);
        add_filter('woocommerce_cart_item_subtotal', [__CLASS__, 'gift_price_html'], 10, 3);
        add_filter('woocommerce_cart_item_name', [__CLASS__, 'gift_name_html'], 10, 3);
        add_filter('woocommerce_get_item_data', [__CLASS__, 'gift_item_data'], 10, 2);
    }

    /* ══════════════════════════════════════════════════════════════
       ORDER LIFECYCLE
       ══════════════════════════════════════════════════════════════ */

    /** Delivered: earn the paws, settle the scratch prize, advance the missions. */
    public static function on_completed($order_id, $order = null): void
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return;
        }
        try {
            $order = self::order($order_id, $order);
            if ($order === null || (int) $order->get_customer_id() <= 0) {
                return;
            }
            Zooboxi_Loyalty_Schema::maybe_install();

            $user_id = (int) $order->get_customer_id();
            Zooboxi_Loyalty_Members::ensure($user_id);

            Zooboxi_Loyalty_Ledger::earn_for_order($order);
            Zooboxi_Loyalty_Scratch::settle_for_order($order);
            Zooboxi_Loyalty_Missions::progress_from_order($order);

            // Phase 2 «العادة»: the on-time bonus, the subscription delivery, the brand
            // stamps, and the referee's first order — each isolated, none may stop the rest.
            foreach ([
                static fn () => class_exists('Zooboxi_Loyalty_Supply') ? Zooboxi_Loyalty_Supply::settle_order($order) : 0,
                static fn () => class_exists('Zooboxi_Loyalty_Subscriptions') ? Zooboxi_Loyalty_Subscriptions::settle_order($order) : 0,
                static fn () => class_exists('Zooboxi_Loyalty_Stamps') ? Zooboxi_Loyalty_Stamps::on_order_completed($order) : 0,
                static fn () => class_exists('Zooboxi_Loyalty_Referrals') ? Zooboxi_Loyalty_Referrals::on_order_completed($order) : null,
            ] as $step) {
                try {
                    $step();
                } catch (\Throwable $e) {
                    error_log('[Zooboxi Loyalty] on_completed (phase 2) step failed: ' . $e->getMessage());
                }
            }
            if (class_exists('Zooboxi_Loyalty_Supply')) {
                Zooboxi_Loyalty_Supply::flush($user_id);
            }
            if (class_exists('Zooboxi_Loyalty_Moments')) {
                Zooboxi_Loyalty_Moments::flush_tier_risk($user_id);
            }

            // The tier is a rolling 12-month count — this order just changed it.
            Zooboxi_Loyalty_Members::recompute_tier($user_id);
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] on_completed failed: ' . $e->getMessage());
        }
    }

    /** Cancelled or refunded: undo whatever this order had already bought. */
    public static function on_reversed($order_id, $order = null): void
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return;
        }
        try {
            $order = self::order($order_id, $order);
            if ($order === null || (int) $order->get_customer_id() <= 0) {
                return;
            }
            Zooboxi_Loyalty_Schema::maybe_install();

            // Paws earned on delivery come back out (a no-op when nothing was earned).
            Zooboxi_Loyalty_Ledger::reverse_for_order($order);
            // A scratch prize waiting on this order will never arrive.
            Zooboxi_Loyalty_Scratch::cancel_for_order((int) $order->get_id());
            // Rewards spent on this basket return to the customer, unharmed.
            Zooboxi_Loyalty_Rewards::restore_for_order((int) $order->get_id());
            // Phase 2 bonuses paid on delivery come back out too.
            if (class_exists('Zooboxi_Loyalty_Supply')) {
                Zooboxi_Loyalty_Supply::reverse_order($order);
                Zooboxi_Loyalty_Supply::flush((int) $order->get_customer_id());
            }
            if (class_exists('Zooboxi_Loyalty_Subscriptions')) {
                Zooboxi_Loyalty_Subscriptions::reverse_order($order);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] on_reversed failed: ' . $e->getMessage());
        }
    }

    /** Any transition can move the 12-month count — mark the cached tier stale. */
    public static function on_status_changed($order_id, $from, $to, $order = null): void
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return;
        }
        try {
            $order = self::order($order_id, $order);
            if ($order === null) {
                return;
            }
            $user_id = (int) $order->get_customer_id();
            if ($user_id > 0) {
                // on_completed() has just recounted; invalidating here would only throw
                // that fresh count away and force a second order query on the next read.
                if ((string) $to !== 'completed') {
                    Zooboxi_Loyalty_Members::invalidate_tier($user_id);
                    if (class_exists('Zooboxi_Loyalty_Moments')) {
                        Zooboxi_Loyalty_Moments::flush_tier_risk($user_id);
                    }
                }
                Zooboxi_Loyalty_Missions::flush_history($user_id);
                if (class_exists('Zooboxi_Loyalty_Supply')) {
                    Zooboxi_Loyalty_Supply::flush($user_id);
                }
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] tier invalidation failed: ' . $e->getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════
       CHECKOUT
       ══════════════════════════════════════════════════════════════ */

    /**
     * The basket became an order: bind every claimed grant to it and mint the scratch
     * card. Fired from the website's classic checkout AND from the v2 `place()`, which
     * calls the same action by hand — one code path, two tills.
     */
    public static function on_order_processed($order_id, $posted_data = [], $order = null): void
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return;
        }
        try {
            $order = self::order($order_id, $order);
            if ($order === null || (int) $order->get_customer_id() <= 0) {
                return;
            }
            Zooboxi_Loyalty_Schema::maybe_install();

            Zooboxi_Loyalty_Rewards::settle_for_order($order);
            Zooboxi_Loyalty_Scratch::create_for_order($order);

            // Phase 2: remember the window the customer ordered IN, and which
            // subscriptions this basket delivers.
            try {
                if (class_exists('Zooboxi_Loyalty_Supply')) {
                    Zooboxi_Loyalty_Supply::stamp_order($order);
                }
                if (class_exists('Zooboxi_Loyalty_Subscriptions')) {
                    Zooboxi_Loyalty_Subscriptions::bind_order($order);
                }
            } catch (\Throwable $e) {
                error_log('[Zooboxi Loyalty] on_order_processed (phase 2) failed: ' . $e->getMessage());
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] on_order_processed failed: ' . $e->getMessage());
        }
    }

    /**
     * Stamp the gift line as it is copied from cart to order.
     *
     * The name prefix lives HERE rather than in a display filter on purpose: the branch
     * picking list, the invoice, the emails and the SAP mirror all read the stored item
     * name, so «🎁 هدية · » has to be part of the record, not part of a theme.
     *
     * @param \WC_Order_Item_Product $item
     */
    public static function on_create_line_item($item, $cart_item_key, $values, $order): void
    {
        if (!Zooboxi_Loyalty::is_enabled() || !($item instanceof \WC_Order_Item_Product) || !is_array($values)) {
            return;
        }
        $grant_id = Zooboxi_Loyalty_Rewards::line_grant_id($values);
        if ($grant_id <= 0) {
            return;
        }
        try {
            $item->update_meta_data(Zooboxi_Loyalty::ORDER_GRANT_META, $grant_id);
            $item->set_name(Zooboxi_Loyalty_Rewards::gift_name((string) $item->get_name()));
            // A visible, non-underscore meta so staff and the customer both see it.
            $item->add_meta_data(__('هدية', 'zooboxi'), __('عائلة زوبوكسي', 'zooboxi'), true);
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] gift line stamp failed: ' . $e->getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════
       CART — the gift line is free, and stays one
       ══════════════════════════════════════════════════════════════ */

    /**
     * Force price 0 and quantity 1 on every gift line, on every totals pass.
     *
     * Direct assignment rather than set_quantity(): we are already INSIDE
     * calculate_totals(), and set_quantity() would call it again.
     */
    public static function enforce_gift_lines($cart): void
    {
        if (!Zooboxi_Loyalty::is_enabled()) {
            return;
        }
        if (!($cart instanceof \WC_Cart)) {
            $cart = Zooboxi_Loyalty::wc_ready() ? WC()->cart : null;
        }
        if (!($cart instanceof \WC_Cart)) {
            return;
        }

        try {
            // Which grants are genuinely claimed into THIS basket? A gift line whose
            // claim is gone (the web cart's "undo" after a removal, a session that was
            // cleared at checkout, a grant that expired) must not ride along at zero.
            $claimed = null;
            foreach ($cart->cart_contents as $key => $item) {
                $grant_id = Zooboxi_Loyalty_Rewards::line_grant_id($item);
                if ($grant_id <= 0) {
                    continue;
                }
                if ($claimed === null) {
                    $claimed = [];
                    $user_id = get_current_user_id();
                    if ($user_id > 0 && Zooboxi_Loyalty_Rewards::has_session()) {
                        foreach (Zooboxi_Loyalty_Rewards::session_claims($user_id) as $grant) {
                            $claimed[(int) $grant['id']] = true;
                        }
                    }
                }
                if (!isset($claimed[$grant_id]) && !Zooboxi_Loyalty_Rewards::is_settling()) {
                    unset($cart->cart_contents[$key]);
                    continue;
                }
                if ((int) ($item['quantity'] ?? 1) !== 1) {
                    $cart->cart_contents[$key]['quantity'] = 1;
                }
                $product = $item['data'] ?? null;
                if ($product instanceof \WC_Product) {
                    $product->set_price(0);
                }
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] gift enforcement failed: ' . $e->getMessage());
        }
    }

    /** Removing the gift line IS how a customer un-claims the reward. */
    public static function on_cart_item_removed($cart_item_key, $cart): void
    {
        if (!Zooboxi_Loyalty::is_enabled() || Zooboxi_Loyalty_Rewards::is_settling()) {
            return;
        }
        try {
            if (!($cart instanceof \WC_Cart)) {
                return;
            }
            $removed = $cart->removed_cart_contents[$cart_item_key] ?? null;
            if (!is_array($removed)) {
                return;
            }
            $grant_id = Zooboxi_Loyalty_Rewards::line_grant_id($removed);
            $user_id  = get_current_user_id();
            if ($grant_id > 0 && $user_id > 0) {
                // The line is already gone — do not try to remove it again.
                Zooboxi_Loyalty_Rewards::unclaim($user_id, $grant_id, false);
            }
        } catch (\Throwable $e) {
            error_log('[Zooboxi Loyalty] un-claim on removal failed: ' . $e->getMessage());
        }
    }

    /** The website's quantity form cannot change a gift. */
    public static function block_gift_quantity($passed, $cart_item_key, $values, $quantity)
    {
        if (!Zooboxi_Loyalty::is_enabled() || !is_array($values)) {
            return $passed;
        }
        if (Zooboxi_Loyalty_Rewards::line_grant_id($values) <= 0) {
            return $passed;
        }
        if ((int) $quantity === 1 || (int) $quantity === 0) {
            return $passed; // 1 = unchanged, 0 = remove (that is allowed: it un-claims)
        }
        if (function_exists('wc_add_notice')) {
            wc_add_notice(__('كمية الهدية ثابتة — هدية واحدة لكل مكافأة.', 'zooboxi'), 'notice');
        }
        return false;
    }

    /* ── Web presentation (the app renders its own cart) ── */

    public static function gift_quantity_html($html, $cart_item_key, $cart_item)
    {
        if (!Zooboxi_Loyalty::is_enabled() || !is_array($cart_item) || Zooboxi_Loyalty_Rewards::line_grant_id($cart_item) <= 0) {
            return $html;
        }
        return '<span class="zb-gift-qty">1</span>';
    }

    public static function gift_price_html($html, $cart_item, $cart_item_key)
    {
        if (!Zooboxi_Loyalty::is_enabled() || !is_array($cart_item) || Zooboxi_Loyalty_Rewards::line_grant_id($cart_item) <= 0) {
            return $html;
        }
        return '<span class="zb-gift-free">' . esc_html__('مجاناً', 'zooboxi') . '</span>';
    }

    public static function gift_name_html($name, $cart_item, $cart_item_key)
    {
        if (!Zooboxi_Loyalty::is_enabled() || !is_array($cart_item) || Zooboxi_Loyalty_Rewards::line_grant_id($cart_item) <= 0) {
            return $name;
        }
        // The stored order name gets the prefix at create_order time; in the cart the
        // line has no order item yet, so the badge is added for display only.
        return '<span class="zb-gift-badge">🎁 ' . esc_html__('هدية', 'zooboxi') . '</span> ' . $name;
    }

    public static function gift_item_data($item_data, $cart_item)
    {
        if (!Zooboxi_Loyalty::is_enabled() || !is_array($cart_item) || Zooboxi_Loyalty_Rewards::line_grant_id($cart_item) <= 0) {
            return $item_data;
        }
        $item_data[] = [
            'key'     => __('هدية', 'zooboxi'),
            'value'   => __('عائلة زوبوكسي', 'zooboxi'),
            'display' => '',
        ];
        return $item_data;
    }

    /* ══════════════════════════════════════════════════════════════
       HELPERS
       ══════════════════════════════════════════════════════════════ */

    private static function order($order_id, $order = null): ?\WC_Order
    {
        if ($order instanceof \WC_Order) {
            return $order;
        }
        if (!function_exists('wc_get_order')) {
            return null;
        }
        $order = wc_get_order((int) $order_id);
        return $order instanceof \WC_Order ? $order : null;
    }
}
