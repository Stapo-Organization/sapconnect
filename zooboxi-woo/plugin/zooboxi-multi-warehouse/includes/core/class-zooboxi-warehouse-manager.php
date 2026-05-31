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
    public static function find_central(string $city): ?array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE city = %s AND is_central = 1 AND is_active = 1 LIMIT 1", $city),
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
