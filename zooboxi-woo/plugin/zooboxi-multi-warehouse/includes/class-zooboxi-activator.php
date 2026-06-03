<?php
/**
 * Plugin Activator — creates custom tables and schedules cron events.
 */
class Zooboxi_Activator
{
    public static function activate(): void
    {
        self::create_tables();
        self::schedule_cron();
        self::set_default_options();
        Zooboxi_OTP_Auth::create_table();
        update_option('zooboxi_version', ZOOBOXI_VERSION);
        flush_rewrite_rules();
    }

    private static function create_tables(): void
    {
        global $wpdb;
        $charset = $wpdb->get_charset_collate();

        $sql_warehouses = "CREATE TABLE IF NOT EXISTS {$wpdb->prefix}zooboxi_warehouses (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            warehouse_code VARCHAR(50) NOT NULL UNIQUE,
            display_name_ar VARCHAR(255),
            display_name_en VARCHAR(255),
            city VARCHAR(100),
            address_ar TEXT,
            address_en TEXT,
            latitude DECIMAL(10,8),
            longitude DECIMAL(11,8),
            express_radius_km DECIMAL(5,2) DEFAULT 10,
            is_express_enabled TINYINT(1) DEFAULT 0,
            express_zone_polygon JSON NULL,
            express_working_hours JSON NULL,
            warehouse_type VARCHAR(20) DEFAULT 'showroom',
            is_central TINYINT(1) DEFAULT 0,
            is_main_hub TINYINT(1) DEFAULT 0,
            is_pickup_enabled TINYINT(1) DEFAULT 1,
            is_active TINYINT(1) DEFAULT 1,
            working_hours JSON,
            phone VARCHAR(20),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) {$charset};";

        $sql_sync_logs = "CREATE TABLE IF NOT EXISTS {$wpdb->prefix}zooboxi_sync_logs (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            sync_type VARCHAR(20) NOT NULL,
            direction VARCHAR(10) DEFAULT 'pull',
            status VARCHAR(20) DEFAULT 'running',
            records_total INT DEFAULT 0,
            records_synced INT DEFAULT 0,
            records_failed INT DEFAULT 0,
            error_message TEXT,
            started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            completed_at TIMESTAMP NULL
        ) {$charset};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql_warehouses);
        dbDelta($sql_sync_logs);
    }

    private static function schedule_cron(): void
    {
        if (!wp_next_scheduled('zooboxi_sync_stock')) {
            wp_schedule_event(time(), 'zooboxi_5_minutes', 'zooboxi_sync_stock');
        }
        if (!wp_next_scheduled('zooboxi_sync_products')) {
            wp_schedule_event(time(), 'hourly', 'zooboxi_sync_products');
        }
        if (!wp_next_scheduled('zooboxi_sync_prices')) {
            wp_schedule_event(time(), 'zooboxi_30_minutes', 'zooboxi_sync_prices');
        }
    }

    private static function set_default_options(): void
    {
        $defaults = [
            'zooboxi_api_url'            => 'https://sapapi.muntajat.sa/api/woo',
            'zooboxi_api_token'          => '',
            'zooboxi_express_fee'        => 15,
            'zooboxi_standard_fee'       => 10,
            'zooboxi_shipping_fee'       => 25,
            'zooboxi_free_shipping_min'  => 200,
            'zooboxi_stock_sync_interval'=> 5,
            'zooboxi_default_price_list' => 1,
        ];

        foreach ($defaults as $key => $value) {
            if (get_option($key) === false) {
                add_option($key, $value);
            }
        }
    }
}
