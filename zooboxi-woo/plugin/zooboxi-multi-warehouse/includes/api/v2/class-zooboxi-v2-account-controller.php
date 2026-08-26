<?php
/**
 * Zooboxi_V2_Account_Controller — wishlist, address book, buy-again.
 *
 * The wishlist is deliberately NOT a second list: it reads and writes the very same
 * user meta the website's heart button uses (`_zbx_wishlist`, theme/inc/zbx-wishlist.php
 * → const ZBX_WISHLIST_META), so a favourite added in the app is already there on the web.
 * Guests get a 401 — exactly what the web AJAX handler returns — so the app can open the
 * phone/OTP sheet instead of silently dropping the tap.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Account_Controller
{
    /** User meta holding the app/web address book. */
    public const ADDRESSES_META = 'zooboxi_addresses';

    private const MAX_ADDRESSES = 20;
    private const BUY_AGAIN_TTL = 900; // 15 minutes

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/wishlist', 'GET', [$this, 'wishlist']);
        Zooboxi_V2_Bootstrap::route('/wishlist/toggle', 'POST', [$this, 'wishlist_toggle']);

        Zooboxi_V2_Bootstrap::route('/addresses', 'GET', [$this, 'addresses']);
        Zooboxi_V2_Bootstrap::route('/addresses', 'POST', [$this, 'create_address']);
        Zooboxi_V2_Bootstrap::route('/addresses/(?P<uuid>[A-Za-z0-9_\-]+)', 'PATCH,PUT', [$this, 'update_address']);
        Zooboxi_V2_Bootstrap::route('/addresses/(?P<uuid>[A-Za-z0-9_\-]+)', 'DELETE', [$this, 'delete_address_route']);
        Zooboxi_V2_Bootstrap::route('/addresses/(?P<uuid>[A-Za-z0-9_\-]+)/default', 'POST', [$this, 'default_address']);

        Zooboxi_V2_Bootstrap::route('/account/buy-again', 'GET', [$this, 'buy_again']);
    }

    /* ══════════════════════════════════════════════════════════════
       WISHLIST
       ══════════════════════════════════════════════════════════════ */

    public function wishlist(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $ids = Zooboxi_Product_DTO::wishlist_ids($user_id);
        $ids = array_values(array_filter($ids, static fn ($id) => get_post_status($id) === 'publish'));

        return Zooboxi_V2_Bootstrap::ok([
            'products' => Zooboxi_Product_DTO::cards($ids),
            'count'    => count($ids),
        ]);
    }

    public function wishlist_toggle(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $product_id = absint($request->get_param('product_id'));
        if (!$product_id || !wc_get_product($product_id)) {
            return Zooboxi_V2_Bootstrap::fail('product_not_found', __('منتج غير معروف', 'zooboxi'), 'Unknown product.', 404);
        }

        // Prefer the theme's own helper when it is loaded — one implementation, one list.
        if (function_exists('zooboxi_wishlist_toggle')) {
            $force  = $request->get_param('force');
            $result = zooboxi_wishlist_toggle($product_id, $user_id, $force === null ? null : (bool) $force);
            return Zooboxi_V2_Bootstrap::ok([
                'wishlisted' => ($result['state'] ?? '') === 'added',
                'count'      => (int) ($result['count'] ?? 0),
            ]);
        }

        // Fallback with the identical meta key + newest-first ordering.
        $ids = Zooboxi_Product_DTO::wishlist_ids($user_id);
        $has = in_array($product_id, $ids, true);
        $add = $request->get_param('force') === null ? !$has : (bool) $request->get_param('force');

        if ($add && !$has) {
            array_unshift($ids, $product_id);
        } elseif (!$add && $has) {
            $ids = array_values(array_diff($ids, [$product_id]));
        }
        $ids = array_slice(array_values(array_unique($ids)), 0, 200);
        update_user_meta($user_id, Zooboxi_Product_DTO::WISHLIST_META, $ids);

        return Zooboxi_V2_Bootstrap::ok(['wishlisted' => $add, 'count' => count($ids)]);
    }

    /* ══════════════════════════════════════════════════════════════
       ADDRESSES
       ══════════════════════════════════════════════════════════════ */

    public function addresses(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        return Zooboxi_V2_Bootstrap::ok(['addresses' => self::get_addresses($user_id)]);
    }

    public function create_address(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $input = self::normalise($request->get_params());
        $error = self::validate($input);
        if ($error !== null) {
            return $error;
        }

        $saved = self::save_address($user_id, $input);
        return Zooboxi_V2_Bootstrap::ok(['address' => $saved, 'addresses' => self::get_addresses($user_id)]);
    }

    public function update_address(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $uuid     = sanitize_text_field((string) $request->get_param('uuid'));
        $existing = self::find_address($user_id, $uuid);
        if (!$existing) {
            return Zooboxi_V2_Bootstrap::fail('address_not_found', __('العنوان غير موجود', 'zooboxi'), 'Address not found.', 404);
        }

        $input       = self::normalise(array_merge($existing, array_filter($request->get_params(), static fn ($v) => $v !== null && $v !== '')));
        $input['id'] = $uuid;

        $error = self::validate($input);
        if ($error !== null) {
            return $error;
        }

        $saved = self::save_address($user_id, $input);
        return Zooboxi_V2_Bootstrap::ok(['address' => $saved, 'addresses' => self::get_addresses($user_id)]);
    }

    public function delete_address_route(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $uuid = sanitize_text_field((string) $request->get_param('uuid'));
        if (!self::find_address($user_id, $uuid)) {
            return Zooboxi_V2_Bootstrap::fail('address_not_found', __('العنوان غير موجود', 'zooboxi'), 'Address not found.', 404);
        }

        $list = array_values(array_filter(self::get_addresses($user_id), static fn ($a) => $a['id'] !== $uuid));
        // Never leave the book without a default.
        if (!empty($list) && !array_filter($list, static fn ($a) => !empty($a['is_default']))) {
            $list[0]['is_default'] = true;
        }
        self::put_addresses($user_id, $list);

        return Zooboxi_V2_Bootstrap::ok(['addresses' => self::get_addresses($user_id)]);
    }

    public function default_address(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $uuid = sanitize_text_field((string) $request->get_param('uuid'));
        if (!self::find_address($user_id, $uuid)) {
            return Zooboxi_V2_Bootstrap::fail('address_not_found', __('العنوان غير موجود', 'zooboxi'), 'Address not found.', 404);
        }

        $list = self::get_addresses($user_id);
        foreach ($list as &$a) {
            $a['is_default'] = ($a['id'] === $uuid);
        }
        unset($a);
        self::put_addresses($user_id, $list);

        return Zooboxi_V2_Bootstrap::ok(['addresses' => self::get_addresses($user_id)]);
    }

    /* ── Address storage (shared with the checkout controller) ── */

    public static function get_addresses(int $user_id): array
    {
        if (!$user_id) {
            return [];
        }
        $raw = get_user_meta($user_id, self::ADDRESSES_META, true);
        if (is_string($raw)) {
            $raw = json_decode($raw, true);
        }
        if (!is_array($raw)) {
            return [];
        }

        $out      = [];
        $repaired = false;
        foreach ($raw as $a) {
            if (!is_array($a) || empty($a['id'])) {
                continue;
            }
            foreach (['label', 'name', 'city', 'district', 'address_line', 'building', 'floor', 'apartment'] as $field) {
                if (isset($a[$field]) && is_string($a[$field])) {
                    $fixed = self::unmangle($a[$field]);
                    if ($fixed !== $a[$field]) {
                        $a[$field] = $fixed;
                        $repaired  = true;
                    }
                }
            }
            $out[] = self::normalise($a);
        }

        // Rows written before the wp_slash fix lost their JSON escapes — once
        // repaired, persist them clean so this path never runs again.
        if ($repaired) {
            update_user_meta(
                $user_id,
                self::ADDRESSES_META,
                wp_slash(wp_json_encode(array_values($out), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES))
            );
        }
        return $out;
    }

    /**
     * Undo the damage update_user_meta's stripslashes did to early rows:
     * `ا` lost its backslash and was stored as the literal text `u0627`.
     * Only strings that are entirely such runs are rebuilt — a real word that
     * merely contains "u1234" is left alone.
     */
    private static function unmangle(string $value): string
    {
        if ($value === '' || !preg_match('/^(?:u[0-9a-fA-F]{4}|[\s\d\p{P}])+$/u', $value)) {
            return $value;
        }
        if (!preg_match('/u[0-9a-fA-F]{4}/', $value)) {
            return $value;
        }
        $json    = '"' . preg_replace('/u([0-9a-fA-F]{4})/', '\\\\u$1', $value) . '"';
        $decoded = json_decode($json);
        return is_string($decoded) ? $decoded : $value;
    }

    public static function find_address(int $user_id, string $id): ?array
    {
        foreach (self::get_addresses($user_id) as $a) {
            if ($a['id'] === $id) {
                return $a;
            }
        }
        return null;
    }

    /** Create or update one entry; keeps exactly one default and mirrors it into WooCommerce. */
    public static function save_address(int $user_id, array $address): array
    {
        $address = self::normalise($address);
        if ($address['id'] === '') {
            $address['id'] = wp_generate_uuid4();
        }
        if ($address['created_at'] === '') {
            $address['created_at'] = current_time('mysql');
        }

        $list    = self::get_addresses($user_id);
        $found   = false;
        foreach ($list as $i => $a) {
            if ($a['id'] === $address['id']) {
                $list[$i] = $address;
                $found    = true;
                break;
            }
        }
        if (!$found) {
            array_unshift($list, $address);
        }
        $list = array_slice($list, 0, self::MAX_ADDRESSES);

        // First address is automatically the default.
        $has_default = (bool) array_filter($list, static fn ($a) => !empty($a['is_default']));
        if (!$has_default || !empty($address['is_default'])) {
            foreach ($list as $i => $a) {
                $list[$i]['is_default'] = ($a['id'] === $address['id']);
            }
        }

        self::put_addresses($user_id, $list);
        return self::find_address($user_id, $address['id']) ?? $address;
    }

    private static function put_addresses(int $user_id, array $list): void
    {
        // UNESCAPED_UNICODE keeps the Arabic readable, and wp_slash compensates
        // for the stripslashes the meta API applies — without it the JSON's
        // backslashes are eaten and ا is stored as the literal "u0627".
        update_user_meta(
            $user_id,
            self::ADDRESSES_META,
            wp_slash(wp_json_encode(array_values($list), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES))
        );
        self::mirror_default_to_woocommerce($user_id, $list);
    }

    /** Keep the WooCommerce billing/shipping user fields in step with the default. */
    private static function mirror_default_to_woocommerce(int $user_id, array $list): void
    {
        $default = null;
        foreach ($list as $a) {
            if (!empty($a['is_default'])) {
                $default = $a;
                break;
            }
        }
        if (!$default) {
            return;
        }

        foreach (['billing', 'shipping'] as $prefix) {
            update_user_meta($user_id, $prefix . '_first_name', $default['name']);
            update_user_meta($user_id, $prefix . '_country', 'SA');
            update_user_meta($user_id, $prefix . '_city', $default['city']);
            update_user_meta($user_id, $prefix . '_address_1', self::compose_line($default));
            update_user_meta($user_id, $prefix . '_address_2', $default['district']);
        }
        if ($default['phone'] !== '') {
            update_user_meta($user_id, 'billing_phone', $default['phone']);
        }
    }

    private static function normalise(array $a): array
    {
        return [
            'id'           => sanitize_text_field((string) ($a['id'] ?? '')),
            'label'        => sanitize_text_field((string) ($a['label'] ?? '')),
            'name'         => sanitize_text_field((string) ($a['name'] ?? '')),
            'phone'        => sanitize_text_field((string) ($a['phone'] ?? '')),
            'city'         => sanitize_text_field((string) ($a['city'] ?? '')),
            'district'     => sanitize_text_field((string) ($a['district'] ?? '')),
            'address_line' => sanitize_text_field((string) ($a['address_line'] ?? '')),
            'building'     => sanitize_text_field((string) ($a['building'] ?? '')),
            'floor'        => sanitize_text_field((string) ($a['floor'] ?? '')),
            'apartment'    => sanitize_text_field((string) ($a['apartment'] ?? '')),
            'lat'          => (float) ($a['lat'] ?? 0),
            'lng'          => (float) ($a['lng'] ?? 0),
            'is_default'   => !empty($a['is_default']),
            'created_at'   => sanitize_text_field((string) ($a['created_at'] ?? '')),
        ];
    }

    /**
     * The one line a driver reads: the unit details, then the free
     * description — «عمارة ٥، الدور ٢، شقة ٣ — بجانب المسجد». WC address_2
     * already carries the district, so everything else lives in address_1.
     */
    public static function compose_line(array $a): string
    {
        $bits = [];
        if (($a['building'] ?? '') !== '') {
            $bits[] = 'عمارة ' . $a['building'];
        }
        if (($a['floor'] ?? '') !== '') {
            $bits[] = 'الدور ' . $a['floor'];
        }
        if (($a['apartment'] ?? '') !== '') {
            $bits[] = 'شقة ' . $a['apartment'];
        }
        $prefix = implode('، ', $bits);
        $line   = (string) ($a['address_line'] ?? '');
        if ($prefix === '') {
            return $line;
        }
        return $line === '' ? $prefix : $prefix . ' — ' . $line;
    }

    private static function validate(array $a): ?\WP_REST_Response
    {
        if ($a['name'] === '') {
            return Zooboxi_V2_Bootstrap::fail('name_required', __('الاسم مطلوب', 'zooboxi'), 'A recipient name is required.', 422);
        }
        if (Zooboxi_OTP_Auth::format_saudi_phone($a['phone']) === '') {
            return Zooboxi_V2_Bootstrap::fail('phone_invalid', __('يرجى إدخال رقم جوال سعودي صالح', 'zooboxi'), 'A valid Saudi mobile number is required.', 422);
        }
        if (!$a['lat'] || !$a['lng'] || abs($a['lat']) > 90 || abs($a['lng']) > 180) {
            return Zooboxi_V2_Bootstrap::fail('coordinates_required', __('حدّد موقع التوصيل على الخريطة', 'zooboxi'), 'Pick the delivery point on the map.', 422);
        }
        // The written details are all optional — the pin's coordinates are
        // the address (the order carries them as meta); text only helps the
        // driver go faster.
        if ($a['city'] === '') {
            return Zooboxi_V2_Bootstrap::fail('city_required', __('المدينة مطلوبة', 'zooboxi'), 'A city is required.', 422);
        }
        return null;
    }

    /* ══════════════════════════════════════════════════════════════
       BUY AGAIN
       ══════════════════════════════════════════════════════════════ */

    public function buy_again(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $key = 'zb_v2_buyagain_' . $user_id;
        $ids = get_transient($key);

        if (!is_array($ids)) {
            // Same order-history rules the website's "اطلبها مجدداً" rail uses.
            $ids = class_exists('Zooboxi_Home_Feed')
                ? Zooboxi_Home_Feed::buyagain_ids($user_id)
                : [];
            set_transient($key, $ids, self::BUY_AGAIN_TTL);
        }

        return Zooboxi_V2_Bootstrap::ok(['products' => Zooboxi_Product_DTO::cards($ids)]);
    }
}
