<?php
/**
 * Location Detector — handles AJAX calls for GPS/manual city detection.
 */
class Zooboxi_Location_Detector
{
    /**
     * Helper: Reverse geocode lat/lng to Saudi City and District using Nominatim.
     */
    public static function reverse_geocode(float $lat, float $lng): array
    {
        $url = sprintf(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=%f&lon=%f&zoom=18&addressdetails=1&accept-language=ar',
            $lat,
            $lng
        );

        $response = wp_remote_get($url, [
            'timeout' => 5,
            'user-agent' => 'Zooboxi-Pet-Store-Agent/1.0 (WordPress)'
        ]);

        if (is_wp_error($response)) {
            return ['city' => '', 'district' => ''];
        }

        $body = wp_remote_retrieve_body($response);
        $data = json_decode($body, true);

        if (empty($data) || !isset($data['address'])) {
            return ['city' => '', 'district' => ''];
        }

        $address = $data['address'];
        
        // Detect city/town
        $city = $address['city'] ?? $address['town'] ?? $address['village'] ?? $address['region'] ?? '';
        
        // Detect Saudi neighborhood/district (usually mapped in 'suburb', 'neighbourhood', 'quarter', or 'subdistrict')
        $district = $address['suburb'] ?? $address['neighbourhood'] ?? $address['quarter'] ?? $address['subdistrict'] ?? '';

        return [
            'city' => sanitize_text_field($city),
            'district' => sanitize_text_field($district)
        ];
    }

    /**
     * AJAX: Detect warehouse from GPS coordinates.
     */
    public static function ajax_detect(): void
    {
        check_ajax_referer('zooboxi_nonce', 'nonce');

        $lat = (float) sanitize_text_field($_POST['lat'] ?? 0);
        $lng = (float) sanitize_text_field($_POST['lng'] ?? 0);

        if (!$lat || !$lng) {
            wp_send_json_error(['message' => __('إحداثيات غير صالحة', 'zooboxi')]);
        }

        // 1. Fetch city and neighborhood
        $geo = self::reverse_geocode($lat, $lng);
        $city = $geo['city'];
        $district = $geo['district'];

        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng, [], $city ?: null);
        $best = $options['express'] ?? $options['standard'] ?? $options['shipping'] ?? null;
        
        // Use geocoded city, never the warehouse name
        // If geocode failed, try to extract city from warehouse name (format: "فرع X - CityName")
        $final_city = $city;
        if (empty($final_city) && $best && !empty($best['warehouse_name'])) {
            $parts = explode(' - ', $best['warehouse_name']);
            $final_city = count($parts) > 1 ? trim(end($parts)) : 'الرياض';
        }
        if (empty($final_city)) {
            $final_city = 'الرياض'; // Saudi Arabia default
        }

        // Save to session
        if (function_exists('WC') && WC()->session) {
            WC()->session->set('zooboxi_customer_lat', $lat);
            WC()->session->set('zooboxi_customer_lng', $lng);
            WC()->session->set('zooboxi_customer_city', $final_city);
            WC()->session->set('zooboxi_customer_district', $district);

            if ($best) {
                WC()->session->set('zooboxi_warehouse_code', $best['warehouse_code']);
                WC()->session->set('zooboxi_delivery_type', $best['delivery_type']);
            }
        }

        // Also store in cookie for non-session/header pages
        setcookie('zooboxi_lat', (string) $lat, time() + 86400 * 30, '/');
        setcookie('zooboxi_lng', (string) $lng, time() + 86400 * 30, '/');
        setcookie('zooboxi_city', $final_city, time() + 86400 * 30, '/');
        setcookie('zooboxi_district', $district, time() + 86400 * 30, '/');
        if ($best) {
            setcookie('zooboxi_branch', $best['warehouse_name'] ?? '', time() + 86400 * 30, '/');
            setcookie('zooboxi_express', !empty($options['express']) ? '1' : '0', time() + 86400 * 30, '/');
            setcookie('zooboxi_delivery_type', $best['delivery_type'] ?? 'shipping', time() + 86400 * 30, '/');
        }

        wp_send_json_success(array_merge($options, [
            'detected_city' => $final_city,
            'detected_district' => $district
        ]));
    }

    /**
     * AJAX: Manual city selection.
     */
    public static function ajax_set_city(): void
    {
        check_ajax_referer('zooboxi_nonce', 'nonce');

        $city = sanitize_text_field($_POST['city'] ?? '');
        if (empty($city)) {
            wp_send_json_error(['message' => __('يرجى اختيار مدينة', 'zooboxi')]);
        }

        $central = Zooboxi_Warehouse_Manager::find_central($city);
        if (!$central) {
            wp_send_json_error(['message' => __('لا يوجد مستودع في هذه المدينة', 'zooboxi')]);
        }

        $lat = (float) $central['latitude'];
        $lng = (float) $central['longitude'];

        if (function_exists('WC') && WC()->session) {
            WC()->session->set('zooboxi_customer_lat', $lat);
            WC()->session->set('zooboxi_customer_lng', $lng);
            WC()->session->set('zooboxi_customer_city', $city);
            WC()->session->set('zooboxi_customer_district', ''); // Clear district on manual city selection
            WC()->session->set('zooboxi_warehouse_code', $central['warehouse_code']);
            WC()->session->set('zooboxi_delivery_type', Zooboxi_Delivery_Engine::TYPE_STANDARD);
        }

        setcookie('zooboxi_lat', (string) $lat, time() + 86400 * 30, '/');
        setcookie('zooboxi_lng', (string) $lng, time() + 86400 * 30, '/');
        setcookie('zooboxi_city', $city, time() + 86400 * 30, '/');
        setcookie('zooboxi_district', '', time() - 3600, '/'); // Remove district on manual selection

        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng);
        wp_send_json_success($options);
    }

    /**
     * Get available cities from active warehouses.
     */
    public static function get_available_cities(): array
    {
        global $wpdb;
        $table = $wpdb->prefix . 'zooboxi_warehouses';
        $cities = $wpdb->get_col("SELECT DISTINCT city FROM {$table} WHERE is_active = 1 AND city IS NOT NULL ORDER BY city");
        return $cities ?: [];
    }
}
