<?php
/**
 * Zooboxi_V2_Cart_Controller — the real WooCommerce cart, driven over REST.
 *
 * WHY NOT THE STORE API: every Zooboxi promise (location-filtered stock, the reachable
 * quantity cap, the four custom shipping methods, the smart-shipments splitter) lives on
 * WooCommerce hooks that only fire around `WC()->cart`. Wrapping the real cart is the
 * only way the app and the website can quote the same numbers.
 *
 * GUEST SESSIONS — the one WooCommerce-internal we depend on: WC identifies a session by
 * a signed cookie whose payload is `customer_id||expiration||expiring||hmac`, and treats
 * any customer id starting with `t_` as a guest (WC_Session_Handler::is_customer_guest).
 * We derive that id deterministically from the device's X-ZB-Guest uuid and hand WC a
 * correctly signed cookie in the in-request superglobal, so the same server-side cart
 * resumes on every call. All of that is contained in seed_guest_session_cookie() +
 * guest_session_key(); if a future WooCommerce changes the format, session_ok() turns
 * false and the routes return a clear `cart_session_unavailable` envelope instead of
 * silently handing back an empty cart.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Cart_Controller
{
    /** Guest session lifetime. */
    private const GUEST_TTL = 30 * DAY_IN_SECONDS;

    private static bool $loaded = false;
    private static string $expected_guest_key = '';
    private static bool $session_ok = true;

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/cart', 'GET', [$this, 'get_cart']);
        Zooboxi_V2_Bootstrap::route('/cart/items', 'POST', [$this, 'add_item']);
        Zooboxi_V2_Bootstrap::route('/cart/items/(?P<key>[A-Za-z0-9_\-]+)', 'PATCH,PUT,POST', [$this, 'update_item']);
        Zooboxi_V2_Bootstrap::route('/cart/items/(?P<key>[A-Za-z0-9_\-]+)', 'DELETE', [$this, 'remove_item']);
        Zooboxi_V2_Bootstrap::route('/cart/coupon', 'POST', [$this, 'apply_coupon']);
        Zooboxi_V2_Bootstrap::route('/cart/coupon/(?P<code>[^/]+)', 'DELETE', [$this, 'remove_coupon']);
    }

    /* ══════════════════════════════════════════════════════════════
       SESSION PLUMBING
       ══════════════════════════════════════════════════════════════ */

    /**
     * Boot WooCommerce's cart for this request. Returns false only when WooCommerce
     * itself is unavailable.
     */
    public static function ensure_cart(?\WP_REST_Request $request = null): bool
    {
        if (self::$loaded) {
            return true;
        }
        if (!function_exists('WC') || !function_exists('wc_load_cart')) {
            return false;
        }

        if (!is_user_logged_in()) {
            $guest = Zooboxi_V2_Bootstrap::guest_id($request);
            if ($guest !== '') {
                self::seed_guest_session_cookie($guest);
            }
        }

        // The location must be in the session BEFORE Zooboxi_Plugin::cap_cart_to_reachable
        // (same hook, priority 20) trims lines to what this customer can receive.
        add_action('woocommerce_cart_loaded_from_session', ['Zooboxi_V2_Bootstrap', 'mirror_location_to_session'], 1);
        wc_load_cart();
        // WC_Cart defers reading the session to `wp_loaded` — long gone by REST
        // dispatch — and only get_cart() lazy-loads it. Without this call the
        // contents stay EMPTY for direct reads: get_cart_item() finds nothing,
        // every update/remove answers item_not_found, while the DTO (which uses
        // get_cart()) happily shows the line. Force the load HERE, while the
        // location mirror above is still armed, so the cap hook also runs
        // against the right coordinates.
        WC()->cart->get_cart();
        remove_action('woocommerce_cart_loaded_from_session', ['Zooboxi_V2_Bootstrap', 'mirror_location_to_session'], 1);

        self::$loaded = (WC()->cart instanceof \WC_Cart);

        if (self::$loaded) {
            Zooboxi_V2_Bootstrap::mirror_location_to_session();

            // Health check: did WooCommerce actually adopt the session we handed it?
            if (self::$expected_guest_key !== '' && WC()->session) {
                self::$session_ok = ((string) WC()->session->get_customer_id() === self::$expected_guest_key);
            }
        }

        return self::$loaded;
    }

    public static function session_ok(): bool
    {
        return self::$session_ok;
    }

    /** Deterministic, WooCommerce-shaped guest session key for a device uuid. */
    public static function guest_session_key(string $guest_id): string
    {
        // "t_" + 30 hex = 32 chars, exactly WC_Session_Handler::generate_customer_id()'s
        // shape, so is_customer_guest() recognises it and session_key (VARCHAR 32) fits.
        return 't_' . substr(hash('sha256', 'zooboxi-guest|' . $guest_id . '|' . wp_salt('auth')), 0, 30);
    }

    private static function session_cookie_name(): string
    {
        return apply_filters('woocommerce_cookie', 'wp_woocommerce_session_' . COOKIEHASH);
    }

    /** Write a correctly signed WooCommerce session cookie into the in-request jar. */
    private static function seed_guest_session_cookie(string $guest_id): void
    {
        if (!defined('COOKIEHASH')) {
            self::$session_ok = false;
            return;
        }

        $customer_id = self::guest_session_key($guest_id);
        $expiration  = time() + self::GUEST_TTL;
        $expiring    = $expiration - HOUR_IN_SECONDS;
        $to_hash     = $customer_id . '|' . $expiration;

        // WC 10 verifies with wp_verify_fast_hash() (WP 6.8+ BLAKE2b, '$generic$…');
        // the HMAC-MD5 form is only the pre-6.8 fallback. Match whichever verifier
        // this install will actually run, or the cookie is silently discarded.
        $hash = function_exists('wp_fast_hash')
            ? wp_fast_hash($to_hash)
            : hash_hmac('md5', $to_hash, wp_hash($to_hash));

        // Modern single-pipe cookie format (WC 10 writes this; '||' is legacy-only).
        $_COOKIE[self::session_cookie_name()] = $customer_id . '|' . $expiration . '|' . $expiring . '|' . $hash;
        self::$expected_guest_key = $customer_id;
    }

    /* ── Guest → user merge (used by the auth controller) ── */

    /**
     * Read a device's guest basket straight out of wp_woocommerce_sessions, without
     * booting a cart for it.
     *
     * @return array<int,array{product_id:int,variation_id:int,quantity:int,variation:array}>
     */
    public static function read_guest_cart_items(string $guest_id): array
    {
        if ($guest_id === '' || !class_exists('WC_Session_Handler')) {
            return [];
        }
        try {
            $handler = new \WC_Session_Handler();
            $data    = $handler->get_session(self::guest_session_key($guest_id), []);
        } catch (\Throwable $e) {
            return [];
        }
        if (!is_array($data) || empty($data['cart'])) {
            return [];
        }

        $cart = maybe_unserialize($data['cart']);
        if (!is_array($cart)) {
            return [];
        }

        $out = [];
        foreach ($cart as $item) {
            if (!is_array($item)) {
                continue;
            }
            $pid = (int) ($item['product_id'] ?? 0);
            if ($pid <= 0) {
                continue;
            }
            $out[] = [
                'product_id'   => $pid,
                'variation_id' => (int) ($item['variation_id'] ?? 0),
                'quantity'     => max(1, (int) ($item['quantity'] ?? 1)),
                'variation'    => is_array($item['variation'] ?? null) ? $item['variation'] : [],
            ];
        }
        return $out;
    }

    /**
     * Add the guest lines on top of the freshly signed-in user's own (persistent) cart.
     * Quantities SUM, because add_to_cart() increments an existing identical line.
     *
     * @return int number of guest lines merged
     */
    public static function merge_guest_items_into_user_cart(array $items, string $guest_id = ''): int
    {
        // Drop the guest cookie so WooCommerce keys the session off the user id and the
        // persistent cart is the base of the merge (not the guest basket).
        if (defined('COOKIEHASH')) {
            unset($_COOKIE[self::session_cookie_name()]);
        }
        self::$loaded             = false;
        self::$expected_guest_key = '';

        if (!self::ensure_cart()) {
            return 0;
        }

        $merged = 0;
        foreach ($items as $i) {
            try {
                $ok = WC()->cart->add_to_cart(
                    (int) $i['product_id'],
                    (int) $i['quantity'],
                    (int) $i['variation_id'],
                    is_array($i['variation']) ? $i['variation'] : []
                );
                if ($ok) {
                    $merged++;
                }
            } catch (\Throwable $e) {
                // A line that is no longer purchasable simply does not travel.
            }
        }

        if ($merged > 0) {
            WC()->cart->calculate_totals();
        }
        if ($guest_id !== '') {
            self::delete_guest_session($guest_id);
        }

        return $merged;
    }

    public static function delete_guest_session(string $guest_id): void
    {
        if ($guest_id === '' || !class_exists('WC_Session_Handler')) {
            return;
        }
        try {
            (new \WC_Session_Handler())->delete_session(self::guest_session_key($guest_id));
        } catch (\Throwable $e) {
            // best effort
        }
    }

    /* ══════════════════════════════════════════════════════════════
       ROUTES
       ══════════════════════════════════════════════════════════════ */

    public function get_cart(\WP_REST_Request $request): \WP_REST_Response
    {
        $boot = self::boot($request, false);
        if ($boot !== null) {
            return $boot;
        }
        // Totals are lazy after a bare session load — line_total/shipping would read 0.
        WC()->cart->calculate_totals();
        return Zooboxi_V2_Bootstrap::ok(self::cart_dto());
    }

    public function add_item(\WP_REST_Request $request): \WP_REST_Response
    {
        $boot = self::boot($request, true);
        if ($boot !== null) {
            return $boot;
        }

        $product_id   = absint($request->get_param('product_id'));
        $variation_id = absint($request->get_param('variation_id'));
        $quantity     = max(1, (int) $request->get_param('quantity'));
        $attributes   = $request->get_param('attributes');
        $variation    = [];

        if (is_array($attributes)) {
            foreach ($attributes as $name => $value) {
                $name = (string) $name;
                if (strpos($name, 'attribute_') !== 0) {
                    $name = 'attribute_' . sanitize_title($name);
                }
                $variation[$name] = sanitize_text_field((string) $value);
            }
        }

        if (!$product_id) {
            return Zooboxi_V2_Bootstrap::fail('product_required', __('منتج غير معروف', 'zooboxi'), 'Unknown product.', 422);
        }
        if (!wc_get_product($variation_id ?: $product_id)) {
            return Zooboxi_V2_Bootstrap::fail('product_not_found', __('منتج غير معروف', 'zooboxi'), 'Unknown product.', 404);
        }

        try {
            $key = WC()->cart->add_to_cart($product_id, $quantity, $variation_id, $variation);
        } catch (\Throwable $e) {
            $key = false;
        }

        if (!$key) {
            return Zooboxi_V2_Bootstrap::fail(
                'add_failed',
                __('تعذّر إضافة المنتج للسلة', 'zooboxi'),
                'The product could not be added to the cart.',
                409,
                self::cart_dto()
            );
        }

        WC()->cart->calculate_totals();
        return Zooboxi_V2_Bootstrap::ok(self::cart_dto(['added_key' => (string) $key]));
    }

    public function update_item(\WP_REST_Request $request): \WP_REST_Response
    {
        $boot = self::boot($request, true);
        if ($boot !== null) {
            return $boot;
        }

        $key = sanitize_text_field((string) $request->get_param('key'));
        $qty = (int) $request->get_param('quantity');

        if (!WC()->cart->get_cart_item($key)) {
            return Zooboxi_V2_Bootstrap::fail('item_not_found', __('هذا الصنف لم يعد في سلتك', 'zooboxi'), 'That line is no longer in your cart.', 404, self::cart_dto());
        }

        if ($qty <= 0) {
            WC()->cart->remove_cart_item($key);
        } else {
            WC()->cart->set_quantity($key, $qty, true);
        }

        WC()->cart->calculate_totals();
        return Zooboxi_V2_Bootstrap::ok(self::cart_dto());
    }

    public function remove_item(\WP_REST_Request $request): \WP_REST_Response
    {
        $boot = self::boot($request, true);
        if ($boot !== null) {
            return $boot;
        }

        $key = sanitize_text_field((string) $request->get_param('key'));
        if (!WC()->cart->get_cart_item($key)) {
            return Zooboxi_V2_Bootstrap::fail('item_not_found', __('هذا الصنف لم يعد في سلتك', 'zooboxi'), 'That line is no longer in your cart.', 404, self::cart_dto());
        }

        WC()->cart->remove_cart_item($key);
        WC()->cart->calculate_totals();
        return Zooboxi_V2_Bootstrap::ok(self::cart_dto());
    }

    public function apply_coupon(\WP_REST_Request $request): \WP_REST_Response
    {
        $boot = self::boot($request, true);
        if ($boot !== null) {
            return $boot;
        }

        $code = wc_format_coupon_code(sanitize_text_field((string) $request->get_param('code')));
        if ($code === '') {
            return Zooboxi_V2_Bootstrap::fail('coupon_required', __('أدخل كود الخصم', 'zooboxi'), 'Enter a coupon code.', 422);
        }
        if (!wc_coupons_enabled()) {
            return Zooboxi_V2_Bootstrap::fail('coupons_disabled', __('أكواد الخصم غير مفعّلة', 'zooboxi'), 'Coupons are disabled.', 409);
        }

        $applied = WC()->cart->apply_coupon($code);
        WC()->cart->calculate_totals();
        $dto = self::cart_dto();

        if (!$applied) {
            return Zooboxi_V2_Bootstrap::fail('coupon_invalid', __('كود الخصم غير صالح', 'zooboxi'), 'That coupon is not valid.', 422, $dto);
        }
        return Zooboxi_V2_Bootstrap::ok($dto);
    }

    public function remove_coupon(\WP_REST_Request $request): \WP_REST_Response
    {
        $boot = self::boot($request, true);
        if ($boot !== null) {
            return $boot;
        }

        $code = wc_format_coupon_code(sanitize_text_field(rawurldecode((string) $request->get_param('code'))));
        WC()->cart->remove_coupon($code);
        WC()->cart->calculate_totals();
        return Zooboxi_V2_Bootstrap::ok(self::cart_dto());
    }

    /* ══════════════════════════════════════════════════════════════
       BOOT GUARD
       ══════════════════════════════════════════════════════════════ */

    /**
     * Load the cart and validate that it can persist. Returns an error response, or
     * null when the caller may proceed.
     */
    private static function boot(\WP_REST_Request $request, bool $mutating): ?\WP_REST_Response
    {
        if ($mutating && !is_user_logged_in() && Zooboxi_V2_Bootstrap::guest_id($request) === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'guest_id_required',
                __('تعذّر تحديد جهازك. أعد فتح التطبيق', 'zooboxi'),
                'A device id (X-ZB-Guest) is required to keep a guest cart.',
                400
            );
        }

        if (!self::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::fail(
                'cart_unavailable',
                __('السلة غير متاحة حالياً', 'zooboxi'),
                'The cart is unavailable right now.',
                503
            );
        }

        if (!self::session_ok()) {
            return Zooboxi_V2_Bootstrap::fail(
                'cart_session_unavailable',
                __('تعذّر حفظ سلتك. حدّث التطبيق أو حاول لاحقاً', 'zooboxi'),
                'The cart session could not be established.',
                503
            );
        }

        return null;
    }

    /* ══════════════════════════════════════════════════════════════
       DTO
       ══════════════════════════════════════════════════════════════ */

    /** The full cart shape returned by every cart mutation. */
    public static function cart_dto(array $extra = []): array
    {
        $cart = WC()->cart;
        [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();

        $items = [];
        foreach ($cart->get_cart() as $key => $item) {
            $product = $item['data'] ?? null;
            if (!($product instanceof \WC_Product)) {
                continue;
            }
            $pid = (int) ($item['product_id'] ?? 0);
            $qty = (int) ($item['quantity'] ?? 0);

            $plan = ($lat && $lng)
                ? Zooboxi_Fulfillment::resolve($pid, max(1, $qty), $lat, $lng)
                : null;

            // Cap like every other stock figure (an exact warehouse count is commercial
            // information) — but never below the line's own qty, or the stepper would
            // wrongly flag an already-valid line as over the limit.
            $raw_reachable = $plan
                ? (int) $plan['reachable_total']
                : (($product->get_stock_quantity() === null) ? null : (int) $product->get_stock_quantity());
            $max_reachable = $raw_reachable === null ? null : min(max($raw_reachable, 0), max(99, $qty));

            $items[] = [
                'key'              => (string) $key,
                'product_id'       => $pid,
                'variation_id'     => (int) ($item['variation_id'] ?? 0),
                'name'             => wp_strip_all_tags($product->get_name()),
                'image'            => Zooboxi_Product_DTO::image_url($product, 'woocommerce_thumbnail'),
                'attributes_label' => trim(wp_strip_all_tags((string) wc_get_formatted_cart_item_data($item, true))),
                'qty'              => $qty,
                'max_reachable'    => $max_reachable,
                'unit_price'       => (float) $product->get_price(),
                'line_subtotal'    => (float) ($item['line_subtotal'] ?? 0),
                'line_total'       => (float) ($item['line_total'] ?? 0),
                'fulfillment'      => $plan ? [
                    'headline'  => Zooboxi_Fulfillment::headline($plan),
                    'tier'      => (string) $plan['slowest'],
                    'is_split'  => (bool) $plan['is_split'],
                    'shortfall' => (int) $plan['shortfall'],
                ] : null,
            ];
        }

        $free_min  = (float) get_option('zooboxi_free_shipping_min', 200);
        $subtotal  = (float) $cart->get_subtotal();
        $qualified = $subtotal >= $free_min;

        $coupons = [];
        foreach ($cart->get_applied_coupons() as $code) {
            $coupons[] = [
                'code'   => (string) $code,
                'amount' => (float) $cart->get_coupon_discount_amount($code),
            ];
        }

        $dto = [
            'items'         => $items,
            'count'         => (int) $cart->get_cart_contents_count(),
            'shipments'     => self::shipments($lat, $lng, $qualified),
            'totals'        => [
                'subtotal' => $subtotal,
                'discount' => (float) $cart->get_discount_total(),
                'shipping' => (float) $cart->get_shipping_total(),
                'tax'      => (float) $cart->get_total_tax(),
                'total'    => (float) $cart->get_total('edit'),
                'currency' => 'SAR',
            ],
            'free_shipping' => [
                'min'       => $free_min,
                'remaining' => max(0, $free_min - $subtotal),
                'qualified' => $qualified,
            ],
            'coupons'       => $coupons,
            'notices'       => self::drain_notices(),
        ];

        return array_merge($dto, $extra);
    }

    /**
     * Delivery shipments for the app. Computed ALWAYS (independent of the web-side
     * `zooboxi_smart_shipments` flag) because the app renders split cards regardless —
     * the flag only governs whether WooCommerce also splits the shipping packages.
     */
    private static function shipments(float $lat, float $lng, bool $free_qualified): array
    {
        if (!$lat || !$lng || !class_exists('Zooboxi_Smart_Shipments')) {
            return [];
        }

        try {
            $groups = Zooboxi_Smart_Shipments::build_tier_groups(WC()->cart->get_cart(), $lat, $lng);
        } catch (\Throwable $e) {
            return [];
        }
        if (empty($groups)) {
            return [];
        }

        $out = [];
        foreach ($groups as $tier => $group) {
            $pres = Zooboxi_Fulfillment::tier_presentation((string) $tier);
            $lines = [];
            foreach ($group['lines'] as $line) {
                $lines[] = [
                    'name' => wp_strip_all_tags((string) ($line['name'] ?? '')),
                    'qty'  => (int) ($line['qty'] ?? 0),
                ];
            }

            $out[] = [
                'tier'           => (string) $tier,
                'label'          => (string) $pres['name'],
                'icon'           => (string) $pres['icon'],
                'color'          => (string) $pres['color'],
                'date_label'     => (string) $pres['date'],
                'relative_label' => (string) $pres['relative'],
                'fee'            => $free_qualified ? 0.0 : self::tier_fee((string) $tier),
                'free'           => $free_qualified,
                'lines'          => $lines,
            ];
        }
        return $out;
    }

    private static function tier_fee(string $tier): float
    {
        switch ($tier) {
            case Zooboxi_Delivery_Engine::TYPE_EXPRESS:
                return (float) get_option('zooboxi_express_fee', 15);
            case Zooboxi_Delivery_Engine::TYPE_STANDARD:
                return (float) get_option('zooboxi_standard_fee', 10);
            default:
                return (float) get_option('zooboxi_shipping_fee', 25);
        }
    }

    /**
     * Surface WooCommerce's notices as JSON and clear them — this is how the
     * cap_cart_to_reachable adjustments ("we lowered the quantity") reach the app.
     */
    public static function drain_notices(): array
    {
        if (!function_exists('wc_get_notices')) {
            return [];
        }
        $out = [];
        foreach (wc_get_notices() as $type => $list) {
            foreach ((array) $list as $notice) {
                $text = is_array($notice) ? (string) ($notice['notice'] ?? '') : (string) $notice;
                $text = trim(wp_strip_all_tags($text));
                if ($text !== '') {
                    $out[] = ['type' => (string) $type, 'text' => $text];
                }
            }
        }
        wc_clear_notices();
        return $out;
    }
}
