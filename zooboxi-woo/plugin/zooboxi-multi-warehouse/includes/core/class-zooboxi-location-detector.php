<?php
/**
 * Location Detector — handles AJAX calls for GPS/manual city detection.
 */
class Zooboxi_Location_Detector
{
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

        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng);

        // Save to session
        if (function_exists('WC') && WC()->session) {
            WC()->session->set('zooboxi_customer_lat', $lat);
            WC()->session->set('zooboxi_customer_lng', $lng);

            // Pick the best delivery type and warehouse
            $best = $options['express'] ?? $options['standard'] ?? $options['shipping'] ?? null;
            if ($best) {
                WC()->session->set('zooboxi_warehouse_code', $best['warehouse_code']);
                WC()->session->set('zooboxi_delivery_type', $best['delivery_type']);
                WC()->session->set('zooboxi_customer_city', $best['warehouse_name'] ?? '');
            }
        }

        // Also store in cookie for non-session pages
        setcookie('zooboxi_lat', (string) $lat, time() + 86400 * 30, '/');
        setcookie('zooboxi_lng', (string) $lng, time() + 86400 * 30, '/');

        wp_send_json_success($options);
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
            WC()->session->set('zooboxi_warehouse_code', $central['warehouse_code']);
            WC()->session->set('zooboxi_delivery_type', Zooboxi_Delivery_Engine::TYPE_STANDARD);
        }

        setcookie('zooboxi_lat', (string) $lat, time() + 86400 * 30, '/');
        setcookie('zooboxi_lng', (string) $lng, time() + 86400 * 30, '/');

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
