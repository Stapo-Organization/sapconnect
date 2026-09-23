<?php
/**
 * Zooboxi_Google_Places — the app's address search, and the Saudi national
 * address under a pin, from Google. Server-side only: the key never ships in
 * the app, every call is cached, and each caller is rate-limited, so nobody can
 * spend the store's Google credit from outside the app.
 *
 * Key: option `zooboxi_google_maps_server_key` when set (the recommended,
 * IP-restricted key), else the website's `zooboxi_google_maps_api_key`.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Google_Places
{
    private const TIMEOUT        = 4;
    private const SEARCH_TTL     = 600;             // 10 min — the same few words are typed all day
    private const DETAILS_TTL    = 30 * DAY_IN_SECONDS;
    private const GEOCODE_TTL    = 30 * DAY_IN_SECONDS;

    /** Requests per caller per hour; a real person types a few dozen. */
    private const LIMIT_PER_HOUR = 240;

    public static function key(): string
    {
        $server = (string) get_option('zooboxi_google_maps_server_key', '');
        return $server !== '' ? $server : (string) get_option('zooboxi_google_maps_api_key', '');
    }

    public static function available(): bool
    {
        return self::key() !== '';
    }

    /**
     * False once this caller (the app's device id, or its IP) has asked too
     * often this hour. Counted per caller, not globally, so one abuser cannot
     * switch search off for everyone else.
     */
    public static function allow(string $caller): bool
    {
        $bucket = 'zb_gp_rl_' . md5($caller) . '_' . gmdate('YmdH');
        $n      = (int) get_transient($bucket);
        if ($n >= self::LIMIT_PER_HOUR) {
            return false;
        }
        set_transient($bucket, $n + 1, HOUR_IN_SECONDS + 60);
        return true;
    }

    /**
     * Place suggestions for what is being typed, Saudi Arabia only, biased to
     * where the customer is.
     *
     * @return array<int, array{id:string,main:string,secondary:string,kind:string,distance_m:?int}>
     */
    public static function autocomplete(string $input, ?float $lat, ?float $lng, string $session, string $lang): array
    {
        $input = trim($input);
        if (mb_strlen($input) < 2 || !self::available()) {
            return [];
        }
        $near  = ($lat && $lng) ? sprintf('%.3f,%.3f', $lat, $lng) : '';
        $cache = 'zb_gp_ac_' . md5($lang . '|' . $near . '|' . mb_strtolower($input));
        $hit   = get_transient($cache);
        if (is_array($hit)) {
            return $hit;
        }

        $args = [
            'input'      => $input,
            'language'   => $lang,
            'components' => 'country:sa',
            'key'        => self::key(),
        ];
        if ($session !== '') {
            $args['sessiontoken'] = $session;
        }
        if ($near !== '') {
            $args['location'] = $near;
            $args['radius']   = 40000;
            $args['origin']   = $near;
        }
        $data = self::get('https://maps.googleapis.com/maps/api/place/autocomplete/json', $args);
        if (!is_array($data) || !in_array($data['status'] ?? '', ['OK', 'ZERO_RESULTS'], true)) {
            return [];
        }

        $out = [];
        foreach ((array) ($data['predictions'] ?? []) as $p) {
            $types = (array) ($p['types'] ?? []);
            $out[] = [
                'id'         => (string) ($p['place_id'] ?? ''),
                'main'       => (string) ($p['structured_formatting']['main_text'] ?? ($p['description'] ?? '')),
                'secondary'  => (string) ($p['structured_formatting']['secondary_text'] ?? ''),
                'kind'       => self::kind($types),
                'distance_m' => isset($p['distance_meters']) ? (int) $p['distance_meters'] : null,
            ];
        }
        $out = array_values(array_filter($out, static fn($r) => $r['id'] !== ''));
        set_transient($cache, $out, self::SEARCH_TTL);
        return $out;
    }

    /** The point a suggestion stands for. */
    public static function details(string $place_id, string $session, string $lang): ?array
    {
        if ($place_id === '' || !self::available()) {
            return null;
        }
        $cache = 'zb_gp_pd_' . md5($lang . '|' . $place_id);
        $hit   = get_transient($cache);
        if (is_array($hit)) {
            return $hit;
        }
        $args = [
            'place_id' => $place_id,
            'fields'   => 'geometry/location,name,formatted_address',
            'language' => $lang,
            'key'      => self::key(),
        ];
        if ($session !== '') {
            $args['sessiontoken'] = $session;
        }
        $data = self::get('https://maps.googleapis.com/maps/api/place/details/json', $args);
        $loc  = $data['result']['geometry']['location'] ?? null;
        if (!is_array($loc) || !isset($loc['lat'], $loc['lng'])) {
            return null;
        }
        $out = [
            'lat'     => (float) $loc['lat'],
            'lng'     => (float) $loc['lng'],
            'name'    => (string) ($data['result']['name'] ?? ''),
            'address' => (string) ($data['result']['formatted_address'] ?? ''),
        ];
        set_transient($cache, $out, self::DETAILS_TTL);
        return $out;
    }

    /**
     * The address under a pin, the way a Saudi driver reads one: the national
     * short address (RANC2412), the building number, the street, the district
     * and the postal code. Null when Google has nothing — the caller keeps its
     * own city/district, which the delivery routing depends on.
     *
     * @return array{short_address:string,building:string,street:string,district:string,postal_code:string}|null
     */
    public static function reverse(float $lat, float $lng, string $lang = 'ar'): ?array
    {
        if (!self::available()) {
            return null;
        }
        $cache = sprintf('zb_gp_rv_%s_%.5f_%.5f', $lang, $lat, $lng);
        $hit   = get_transient($cache);
        if (is_array($hit)) {
            return $hit ?: null;
        }
        $data = self::get('https://maps.googleapis.com/maps/api/geocode/json', [
            'latlng'   => sprintf('%.6f,%.6f', $lat, $lng),
            'language' => $lang,
            'key'      => self::key(),
        ]);
        $results = (array) ($data['results'] ?? []);
        $out     = [];
        foreach ($results as $r) {
            $parts = [];
            foreach ((array) ($r['address_components'] ?? []) as $c) {
                foreach ((array) ($c['types'] ?? []) as $t) {
                    $parts[$t] = $parts[$t] ?? (string) ($c['long_name'] ?? '');
                }
            }
            // The first result that is a building on a street is the door.
            if (!empty($parts['route']) || !empty($parts['street_number'])) {
                $premise = (string) ($parts['premise'] ?? '');
                $out = [
                    // Saudi National Address short code: four letters, four digits.
                    'short_address' => preg_match('/^[A-Z]{4}\d{4}$/', $premise) ? $premise : '',
                    'building'      => (string) ($parts['street_number'] ?? ''),
                    'street'        => (string) ($parts['route'] ?? ''),
                    'district'      => (string) ($parts['political'] ?? $parts['sublocality'] ?? $parts['neighborhood'] ?? ''),
                    'postal_code'   => (string) ($parts['postal_code'] ?? ''),
                ];
                break;
            }
        }
        // An empty answer is cached too, as an empty array: no point asking again.
        set_transient($cache, $out, self::GEOCODE_TTL);
        return $out ?: null;
    }

    /** Google's place types → the few icons the app draws. */
    private static function kind(array $types): string
    {
        foreach ($types as $t) {
            switch ($t) {
                case 'neighborhood':
                case 'sublocality':
                case 'sublocality_level_1':
                case 'locality':
                case 'political':
                    return 'area';
                case 'route':
                case 'street_address':
                case 'premise':
                    return 'street';
                case 'park':
                    return 'park';
                case 'restaurant':
                case 'food':
                case 'cafe':
                    return 'food';
                case 'mosque':
                case 'place_of_worship':
                    return 'mosque';
                case 'school':
                case 'university':
                    return 'school';
                case 'hospital':
                case 'health':
                    return 'health';
            }
        }
        return in_array('establishment', $types, true) ? 'place' : 'area';
    }

    private static function get(string $url, array $args): ?array
    {
        $response = wp_remote_get(add_query_arg(array_map('rawurlencode', $args), $url), [
            'timeout'    => self::TIMEOUT,
            'user-agent' => 'Zooboxi/1.0 (store.zooboxi.com)',
        ]);
        if (is_wp_error($response) || (int) wp_remote_retrieve_response_code($response) !== 200) {
            return null;
        }
        $data = json_decode((string) wp_remote_retrieve_body($response), true);
        return is_array($data) ? $data : null;
    }
}
