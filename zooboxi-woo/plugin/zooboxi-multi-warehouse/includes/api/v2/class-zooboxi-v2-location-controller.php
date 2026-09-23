<?php
/**
 * Zooboxi_V2_Location_Controller — city list, GPS resolution and pickup points.
 *
 * These endpoints are PURE: they never write the customer's location into a session or
 * cookie. The app owns the location and replays it on every request as X-ZB-* headers,
 * which the bootstrap seeds for the rest of the plugin.
 */
if (!defined('ABSPATH')) {
    exit;
}

require_once __DIR__ . '/../../core/class-zooboxi-google-places.php';

class Zooboxi_V2_Location_Controller
{
    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/location/cities', 'GET', [$this, 'cities']);
        Zooboxi_V2_Bootstrap::route('/location/resolve', 'POST', [$this, 'resolve']);
        Zooboxi_V2_Bootstrap::route('/location/pickup-points', 'GET', [$this, 'pickup_points']);
        Zooboxi_V2_Bootstrap::route('/location/search', 'GET', [$this, 'search']);
        Zooboxi_V2_Bootstrap::route('/location/place', 'GET', [$this, 'place']);
    }

    /* ── GET /location/cities ──────────────────────── */

    public function cities(\WP_REST_Request $request): \WP_REST_Response
    {
        $out  = [];
        $seen = [];
        $lang = Zooboxi_V2_Bootstrap::lang();
        foreach (Zooboxi_Location_Detector::get_available_cities() as $city) {
            // One row per city in the requested language: the table spells
            // some cities twice («الدمام» and "Dammam"), and both matched.
            $city = Zooboxi_Warehouse_Manager::city_label((string) $city, $lang);
            if ($city === '' || isset($seen[$city])) {
                continue;
            }
            $seen[$city] = true;
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            $out[] = [
                'city'        => $city,
                'has_central' => (bool) $central,
                'central'     => $central ? [
                    'code' => (string) ($central['warehouse_code'] ?? ''),
                    'name' => self::wh_name($central),
                    'lat'  => (float) ($central['latitude'] ?? 0),
                    'lng'  => (float) ($central['longitude'] ?? 0),
                ] : null,
            ];
        }

        return Zooboxi_V2_Bootstrap::ok(['cities' => $out], Zooboxi_V2_Bootstrap::TTL_CATEGORIES);
    }

    /* ── POST /location/resolve ────────────────────── */

    public function resolve(\WP_REST_Request $request): \WP_REST_Response
    {
        $lat = (float) $request->get_param('lat');
        $lng = (float) $request->get_param('lng');

        if (!$lat || !$lng || abs($lat) > 90 || abs($lng) > 180) {
            return Zooboxi_V2_Bootstrap::fail(
                'invalid_coordinates',
                __('إحداثيات غير صالحة', 'zooboxi'),
                'Invalid coordinates.',
                422
            );
        }

        $geo      = Zooboxi_Location_Detector::reverse_geocode($lat, $lng);
        $city     = (string) ($geo['city'] ?? '');
        $district = (string) ($geo['district'] ?? '');

        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng, [], $city !== '' ? $city : null);
        $best    = $options['express'] ?? $options['standard'] ?? $options['shipping'] ?? null;

        // Same fallback ladder as the web detector: geocoded city → warehouse name tail → Riyadh.
        if ($city === '' && $best && !empty($best['warehouse_name'])) {
            $parts = explode(' - ', (string) $best['warehouse_name']);
            $city  = count($parts) > 1 ? trim(end($parts)) : 'الرياض';
        }
        if ($city === '') {
            $city = 'الرياض';
        }

        // The door itself, from Google: national short address, building,
        // street, postal code. Additive — city/district above stay the ones the
        // delivery routing knows.
        $door = class_exists('Zooboxi_Google_Places')
            ? Zooboxi_Google_Places::reverse($lat, $lng, Zooboxi_V2_Bootstrap::lang() === 'en' ? 'en' : 'ar')
            : null;
        if ($district === '' && $door && $door['district'] !== '') {
            $district = $door['district'];
        }

        return Zooboxi_V2_Bootstrap::ok([
            // Kept as the store spells it: the app echoes this value back as
            // the scope's city key, so it must match the warehouse rows.
            'city'     => $city,
            'district' => $district,
            'address'  => $door,
            'options'  => [
                'express'  => self::option_dto($options['express'] ?? null),
                'standard' => self::option_dto($options['standard'] ?? null),
                'shipping' => self::option_dto($options['shipping'] ?? null),
                'pickup'   => array_map([self::class, 'pickup_dto'], array_values((array) ($options['pickup'] ?? []))),
            ],
            'best'     => $best ? [
                'delivery_type'  => (string) ($best['delivery_type'] ?? ''),
                'warehouse_code' => (string) ($best['warehouse_code'] ?? ''),
                'warehouse_name' => (string) ($best['warehouse_name'] ?? ''),
                'promise_label'  => (string) ($best['estimated_time'] ?? ''),
                'fee'            => (float) ($best['fee'] ?? 0),
            ] : null,
        ]);
    }

    /* ── GET /location/search?q=&lat=&lng=&session= ── */

    /**
     * Address search for the app's map: Google place suggestions, Saudi Arabia
     * only, near the customer. Only the app may ask (its device id or its
     * token), and each caller is rate-limited.
     */
    public function search(\WP_REST_Request $request): \WP_REST_Response
    {
        $caller = self::caller($request);
        if ($caller === '') {
            return Zooboxi_V2_Bootstrap::fail('forbidden', __('غير مسموح', 'zooboxi'), 'Forbidden.', 403);
        }
        if (!Zooboxi_Google_Places::allow($caller)) {
            return Zooboxi_V2_Bootstrap::fail('rate_limited', __('محاولات كثيرة، جرّب بعد قليل', 'zooboxi'), 'Too many requests.', 429);
        }
        $q   = sanitize_text_field((string) $request->get_param('q'));
        $lat = (float) $request->get_param('lat');
        $lng = (float) $request->get_param('lng');
        $results = Zooboxi_Google_Places::autocomplete(
            $q,
            $lat ?: null,
            $lng ?: null,
            substr(preg_replace('/[^A-Za-z0-9-]/', '', (string) $request->get_param('session')), 0, 64),
            Zooboxi_V2_Bootstrap::lang() === 'en' ? 'en' : 'ar'
        );
        return Zooboxi_V2_Bootstrap::ok(['results' => $results], null);
    }

    /* ── GET /location/place?id=&session= ───────────── */

    public function place(\WP_REST_Request $request): \WP_REST_Response
    {
        $caller = self::caller($request);
        if ($caller === '') {
            return Zooboxi_V2_Bootstrap::fail('forbidden', __('غير مسموح', 'zooboxi'), 'Forbidden.', 403);
        }
        if (!Zooboxi_Google_Places::allow($caller)) {
            return Zooboxi_V2_Bootstrap::fail('rate_limited', __('محاولات كثيرة، جرّب بعد قليل', 'zooboxi'), 'Too many requests.', 429);
        }
        $place = Zooboxi_Google_Places::details(
            sanitize_text_field((string) $request->get_param('id')),
            substr(preg_replace('/[^A-Za-z0-9-]/', '', (string) $request->get_param('session')), 0, 64),
            Zooboxi_V2_Bootstrap::lang() === 'en' ? 'en' : 'ar'
        );
        if ($place === null) {
            return Zooboxi_V2_Bootstrap::fail('place_not_found', __('المكان غير موجود', 'zooboxi'), 'Place not found.', 404);
        }
        return Zooboxi_V2_Bootstrap::ok(['place' => $place], null);
    }

    /** Who is asking: the signed-in customer, else the app's device id. '' = not the app. */
    private static function caller(\WP_REST_Request $request): string
    {
        $uid = Zooboxi_V2_Bootstrap::token_user();
        if ($uid > 0) {
            return 'u' . $uid;
        }
        $guest = preg_replace('/[^A-Za-z0-9-]/', '', (string) $request->get_header('X-ZB-Guest'));
        if ($guest !== '' && strlen($guest) >= 16) {
            return 'g' . $guest . '|' . ($_SERVER['REMOTE_ADDR'] ?? '');
        }
        return '';
    }

    /* ── GET /location/pickup-points ───────────────── */

    public function pickup_points(\WP_REST_Request $request): \WP_REST_Response
    {
        $lat = (float) $request->get_param('lat');
        $lng = (float) $request->get_param('lng');

        if (!$lat || !$lng) {
            [$lat, $lng] = Zooboxi_V2_Bootstrap::latlng();
        }
        if (!$lat || !$lng) {
            return Zooboxi_V2_Bootstrap::fail(
                'invalid_coordinates',
                __('إحداثيات غير صالحة', 'zooboxi'),
                'Coordinates are required.',
                422
            );
        }

        $out = [];
        foreach (array_slice(Zooboxi_Warehouse_Manager::get_pickup_locations($lat, $lng), 0, 10) as $p) {
            $wh = $p['warehouse'] ?? [];
            $out[] = [
                'warehouse_code' => (string) ($wh['warehouse_code'] ?? ''),
                'warehouse_name' => self::wh_name($wh),
                'address'        => Zooboxi_V2_Bootstrap::pick((string) ($wh['address_ar'] ?? ''), (string) ($wh['address_en'] ?? '')),
                'city'           => Zooboxi_Warehouse_Manager::city_label((string) ($wh['city'] ?? ''), Zooboxi_V2_Bootstrap::lang()),
                'lat'            => (float) ($wh['latitude'] ?? 0),
                'lng'            => (float) ($wh['longitude'] ?? 0),
                'distance_km'    => (float) ($p['distance'] ?? 0),
                'phone'          => (string) ($wh['phone'] ?? ''),
            ];
        }

        return Zooboxi_V2_Bootstrap::ok(['pickup_points' => $out]);
    }

    /* ── Helpers (explicit allowlists) ─────────────── */

    private static function option_dto($option): ?array
    {
        if (!is_array($option) || empty($option)) {
            return null;
        }
        return [
            'delivery_type'  => (string) ($option['delivery_type'] ?? ''),
            'warehouse_code' => (string) ($option['warehouse_code'] ?? ''),
            'warehouse_name' => (string) ($option['warehouse_name'] ?? ''),
            'estimated_time' => (string) ($option['estimated_time'] ?? ''),
            'fee'            => (float) ($option['fee'] ?? 0),
            'distance_km'    => isset($option['distance_km']) ? (float) $option['distance_km'] : null,
        ];
    }

    private static function pickup_dto($p): array
    {
        $p = is_array($p) ? $p : [];
        return [
            'warehouse_code' => (string) ($p['warehouse_code'] ?? ''),
            'warehouse_name' => (string) ($p['warehouse_name'] ?? ''),
            'address'        => (string) ($p['address'] ?? ''),
            'distance_km'    => (float) ($p['distance_km'] ?? 0),
            'phone'          => (string) ($p['phone'] ?? ''),
            'fee'            => 0.0,
        ];
    }

    private static function wh_name($wh): string
    {
        $wh = is_array($wh) ? $wh : [];
        return Zooboxi_V2_Bootstrap::pick(
            (string) ($wh['display_name_ar'] ?? ''),
            (string) ($wh['display_name_en'] ?? '')
        );
    }
}
