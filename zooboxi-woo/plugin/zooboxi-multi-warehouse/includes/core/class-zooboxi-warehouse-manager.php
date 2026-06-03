<?php
/**
 * Manages Zooboxi warehouses (CRUD + proximity queries).
 * Data source: wp_zooboxi_warehouses table (synced from sapconnect).
 */
class Zooboxi_Warehouse_Manager
{
    /**
     * Get all active warehouses.
     */
    public static function get_active(): array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';
        return $wpdb->get_results("SELECT * FROM {$table} WHERE is_active = 1", ARRAY_A) ?: [];
    }

    /**
     * Find the nearest warehouse to a GPS position.
     * Returns ['warehouse' => row, 'distance' => km] or null.
     */
    public static function find_nearest(float $lat, float $lng): ?array
    {
        $warehouses = self::get_active();
        $best = null;

        foreach ($warehouses as $wh) {
            if (!$wh['latitude'] || !$wh['longitude']) continue;

            $dist = Zooboxi_Geo_Helper::distance($lat, $lng, (float) $wh['latitude'], (float) $wh['longitude']);
            if ($best === null || $dist < $best['distance']) {
                $best = ['warehouse' => $wh, 'distance' => round($dist, 2)];
            }
        }

        return $best;
    }

    /**
     * Find a central warehouse in a given city.
     */
    /**
     * Arabic ↔ English city name map for matching.
     */
    private static array $cityMap = [
        'الرياض'          => 'Riyadh',
        'جدة'             => 'Jeddah',
        'جده'             => 'Jeddah',
        'الدمام'          => 'Dammam',
        'المدينة المنورة' => 'Madinah',
        'المدينة'         => 'Madinah',
        'مكة المكرمة'     => 'Makkah',
        'مكة'             => 'Makkah',
        'أبها'            => 'Abha',
        'الخبر'           => 'Khobar',
        'الطائف'          => 'Taif',
        'تبوك'            => 'Tabuk',
        'بريدة'           => 'Buraydah',
        'عنيزة'           => 'Unayzah',
        'حائل'            => 'Hail',
        'نجران'           => 'Najran',
        'جازان'           => 'Jazan',
        'ينبع'            => 'Yanbu',
        'القصيم'          => 'Qassim',
        'الباحة'          => 'Al Baha',
        'الجوف'           => 'Al Jouf',
    ];

    public static function find_central(string $city): ?array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';

        // 1. Try exact match first
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE city = %s AND is_central = 1 AND is_active = 1 LIMIT 1", $city),
            ARRAY_A
        );
        if ($row) return $row;

        // 2. Try bilingual mapping (Arabic → English or English → Arabic)
        $altCity = self::$cityMap[$city] ?? array_search($city, self::$cityMap, true);
        if ($altCity && $altCity !== false) {
            $row = $wpdb->get_row(
                $wpdb->prepare("SELECT * FROM {$table} WHERE city = %s AND is_central = 1 AND is_active = 1 LIMIT 1", $altCity),
                ARRAY_A
            );
            if ($row) return $row;
        }

        // 3. Try case-insensitive LIKE as last resort
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE city LIKE %s AND is_central = 1 AND is_active = 1 LIMIT 1", '%' . $wpdb->esc_like($city) . '%'),
            ARRAY_A
        );
        return $row ?: null;
    }

    /**
     * Get the main hub warehouse (for national shipping).
     */
    public static function get_main_hub(): ?array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';
        $row = $wpdb->get_row("SELECT * FROM {$table} WHERE is_main_hub = 1 AND is_active = 1 LIMIT 1", ARRAY_A);
        return $row ?: null;
    }

    /**
     * Get warehouses that support pickup, sorted by distance.
     */
    public static function get_pickup_locations(float $lat, float $lng): array
    {
        $warehouses = self::get_active();
        $results = [];

        foreach ($warehouses as $wh) {
            if (!$wh['is_pickup_enabled'] || !$wh['latitude'] || !$wh['longitude']) continue;

            $dist = Zooboxi_Geo_Helper::distance($lat, $lng, (float) $wh['latitude'], (float) $wh['longitude']);
            $results[] = ['warehouse' => $wh, 'distance' => round($dist, 2)];
        }

        usort($results, fn($a, $b) => $a['distance'] <=> $b['distance']);
        return $results;
    }

    /**
     * Find all express-enabled warehouses where the customer is within the express zone
     * AND the warehouse is currently within working hours.
     * Returns array of ['warehouse' => row, 'distance' => km] sorted by distance.
     */
    public static function find_express_warehouses(float $lat, float $lng): array
    {
        $warehouses = self::get_active();
        $results = [];

        foreach ($warehouses as $wh) {
            if (empty($wh['is_express_enabled'])) continue;
            if (!$wh['latitude'] || !$wh['longitude']) continue;

            // Check zone: polygon first, fallback to radius
            if (!self::is_within_express_zone($wh, $lat, $lng)) continue;

            // Check working hours
            if (!self::is_within_working_hours($wh)) continue;

            $dist = Zooboxi_Geo_Helper::distance($lat, $lng, (float) $wh['latitude'], (float) $wh['longitude']);
            $results[] = ['warehouse' => $wh, 'distance' => round($dist, 2)];
        }

        usort($results, fn($a, $b) => $a['distance'] <=> $b['distance']);
        return $results;
    }

    /**
     * Check if customer coordinates fall within a warehouse's express zone.
     * Uses GeoJSON polygon if available, falls back to circular radius.
     */
    public static function is_within_express_zone(array $warehouse, float $lat, float $lng): bool
    {
        // Try polygon zone first
        $polygon_raw = $warehouse['express_zone_polygon'] ?? null;
        if (!empty($polygon_raw)) {
            $polygon = is_string($polygon_raw) ? json_decode($polygon_raw, true) : $polygon_raw;
            if (!empty($polygon['coordinates'])) {
                return Zooboxi_Geo_Helper::point_in_polygon($lat, $lng, $polygon);
            }
        }

        // Fallback: circular radius
        $radius = (float) ($warehouse['express_radius_km'] ?? 10);
        $whLat = (float) ($warehouse['latitude'] ?? 0);
        $whLng = (float) ($warehouse['longitude'] ?? 0);

        if (!$whLat || !$whLng) return false;

        return Zooboxi_Geo_Helper::is_within_radius($lat, $lng, $whLat, $whLng, $radius);
    }

    /**
     * Check if a warehouse is currently within its express working hours (KSA timezone).
     */
    public static function is_within_working_hours(array $warehouse): bool
    {
        $hours_raw = $warehouse['express_working_hours'] ?? null;

        // If no working hours defined, assume always available
        if (empty($hours_raw)) return true;

        $hours = is_string($hours_raw) ? json_decode($hours_raw, true) : $hours_raw;
        if (empty($hours) || !is_array($hours)) return true;

        // Current KSA time
        try {
            $now = new \DateTime('now', new \DateTimeZone('Asia/Riyadh'));
        } catch (\Exception $e) {
            return true; // Failsafe: assume available
        }

        $dayName = strtolower($now->format('l')); // sunday, monday, etc.
        $currentTime = $now->format('H:i');

        if (!isset($hours[$dayName])) return false; // Day not in schedule = closed

        $dayHours = $hours[$dayName];

        // Handle 'closed' flag
        if (isset($dayHours['closed']) && $dayHours['closed']) return false;

        $open = $dayHours['open'] ?? '00:00';
        $close = $dayHours['close'] ?? '23:59';

        // Handle overnight hours (e.g. open 09:00, close 02:00 next day)
        if ($close <= $open) {
            // Overnight: current >= open OR current <= close
            return $currentTime >= $open || $currentTime <= $close;
        }

        // Normal: open <= current <= close
        return $currentTime >= $open && $currentTime <= $close;
    }

    /**
     * Get all showrooms with express delivery enabled.
     */
    public static function get_express_showrooms(): array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';
        $rows = $wpdb->get_results(
            "SELECT * FROM {$table} WHERE is_express_enabled = 1 AND is_active = 1",
            ARRAY_A
        );
        return $rows ?: [];
    }

    /**
     * Upsert a warehouse (used during sync from sapconnect).
     */
    public static function upsert(array $data): void
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';

        // Filter to valid columns only
        $valid_keys = [
            'warehouse_code', 'display_name_ar', 'display_name_en',
            'city', 'address_ar', 'address_en',
            'latitude', 'longitude', 'express_radius_km',
            'is_express_enabled', 'express_zone_polygon', 'express_working_hours',
            'warehouse_type',
            'is_central', 'is_main_hub', 'is_pickup_enabled', 'is_active',
            'working_hours', 'phone',
        ];
        $filtered = array_intersect_key($data, array_flip($valid_keys));

        // Convert working_hours to JSON if it's an array
        if (isset($filtered['working_hours']) && is_array($filtered['working_hours'])) {
            $filtered['working_hours'] = wp_json_encode($filtered['working_hours']);
        }

        $existing = $wpdb->get_var($wpdb->prepare(
            "SELECT id FROM {$table} WHERE warehouse_code = %s",
            $filtered['warehouse_code']
        ));

        if ($existing) {
            $wpdb->update($table, $filtered, ['warehouse_code' => $filtered['warehouse_code']]);
        } else {
            $result = $wpdb->insert($table, $filtered);
            if ($result === false) {
                error_log("Zooboxi Warehouse insert error: " . $wpdb->last_error);
            }
        }
    }
}
