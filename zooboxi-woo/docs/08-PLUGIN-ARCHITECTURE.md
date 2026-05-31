# 08 — بنية البلقن المخصص (Zooboxi Multi-Warehouse Plugin)

## نظرة عامة

البلقن المخصص **zooboxi-multi-warehouse** هو قلب نظام Zooboxi. يدير:

1. **المستودعات المتعددة** وإعداداتها الجغرافية
2. **محرك التوصيل الذكي** (Express, Standard, Shipping, Pickup)
3. **مزامنة البيانات** مع sapconnect
4. **تحديد الموقع** والمستودع الأنسب
5. **إدارة المخزون** لكل مستودع
6. **لوحة تحكم** في WordPress Admin

---

## هيكل البلقن

```
zooboxi-multi-warehouse/
├── zooboxi-multi-warehouse.php          # Main plugin file
├── readme.txt                            # WordPress plugin readme
├── uninstall.php                         # Cleanup on uninstall
│
├── includes/
│   ├── class-zooboxi-plugin.php         # Main plugin class (singleton)
│   ├── class-zooboxi-activator.php      # Activation hooks
│   ├── class-zooboxi-deactivator.php    # Deactivation hooks
│   │
│   ├── core/
│   │   ├── class-zooboxi-warehouse-manager.php    # إدارة المستودعات
│   │   ├── class-zooboxi-stock-manager.php        # إدارة المخزون
│   │   ├── class-zooboxi-delivery-engine.php      # محرك التوصيل الذكي
│   │   ├── class-zooboxi-location-detector.php    # تحديد موقع العميل
│   │   └── class-zooboxi-geo-helper.php           # حسابات جغرافية
│   │
│   ├── sync/
│   │   ├── class-zooboxi-sync-engine.php          # محرك المزامنة الرئيسي
│   │   ├── class-zooboxi-product-sync.php         # مزامنة المنتجات
│   │   ├── class-zooboxi-stock-sync.php           # مزامنة المخزون
│   │   ├── class-zooboxi-price-sync.php           # مزامنة الأسعار
│   │   ├── class-zooboxi-order-sync.php           # مزامنة الطلبات
│   │   └── class-zooboxi-logger.php               # تسجيل المزامنة
│   │
│   ├── shipping/
│   │   ├── class-zooboxi-express-shipping.php     # توصيل سريع (2 ساعة)
│   │   ├── class-zooboxi-standard-shipping.php    # توصيل عادي (24 ساعة)
│   │   ├── class-zooboxi-national-shipping.php    # شحن وطني (2-4 أيام)
│   │   └── class-zooboxi-pickup-shipping.php      # استلام من الفرع
│   │
│   ├── admin/
│   │   ├── class-zooboxi-admin.php                # لوحة التحكم
│   │   ├── class-zooboxi-settings-page.php        # صفحة الإعدادات
│   │   ├── class-zooboxi-warehouse-admin.php      # إدارة المستودعات
│   │   ├── class-zooboxi-sync-dashboard.php       # لوحة المزامنة
│   │   └── class-zooboxi-order-dashboard.php      # لوحة الطلبات
│   │
│   ├── frontend/
│   │   ├── class-zooboxi-location-popup.php       # نافذة تحديد الموقع
│   │   ├── class-zooboxi-delivery-badge.php       # شارة التوصيل
│   │   ├── class-zooboxi-product-stock-display.php # عرض المخزون
│   │   └── class-zooboxi-checkout-customizer.php  # تخصيص Checkout
│   │
│   └── api/
│       ├── class-zooboxi-rest-controller.php      # REST API endpoints
│       └── class-zooboxi-webhook-handler.php      # Webhook handler
│
├── admin/
│   ├── css/
│   │   └── zooboxi-admin.css                      # Admin styles
│   ├── js/
│   │   └── zooboxi-admin.js                       # Admin scripts
│   └── views/
│       ├── settings-page.php                       # Settings HTML
│       ├── warehouse-list.php                      # Warehouse list HTML
│       ├── warehouse-edit.php                      # Edit warehouse HTML
│       ├── sync-dashboard.php                      # Sync dashboard HTML
│       └── order-dashboard.php                     # Order dashboard HTML
│
├── public/
│   ├── css/
│   │   ├── zooboxi-public.css                     # Frontend styles
│   │   └── zooboxi-rtl.css                        # RTL overrides
│   ├── js/
│   │   ├── zooboxi-location.js                    # Location detection
│   │   ├── zooboxi-delivery.js                    # Delivery display
│   │   └── zooboxi-checkout.js                    # Checkout enhancements
│   └── views/
│       ├── location-popup.php                      # Location modal
│       ├── delivery-badge.php                      # Delivery badge
│       └── pickup-selector.php                     # Branch selector
│
└── languages/
    ├── zooboxi-multi-warehouse-ar.po               # Arabic translations
    ├── zooboxi-multi-warehouse-ar.mo
    └── zooboxi-multi-warehouse.pot                 # Translation template
```

---

## Main Plugin File

```php
<?php
/**
 * Plugin Name: Zooboxi Multi-Warehouse
 * Plugin URI:  https://zooboxi.com
 * Description: نظام المستودعات المتعددة والتوصيل الذكي لمتجر Zooboxi
 * Version:     1.0.0
 * Author:      Muntajat / PPTCO
 * Author URI:  https://muntajat.sa
 * License:     Proprietary
 * Text Domain: zooboxi
 * Domain Path: /languages
 * Requires at least: 6.5
 * Tested up to: 6.8
 * WC requires at least: 9.0
 * WC tested up to: 9.8
 * Requires PHP: 8.1
 */

defined('ABSPATH') || exit;

// Plugin constants
define('ZOOBOXI_VERSION', '1.0.0');
define('ZOOBOXI_PLUGIN_FILE', __FILE__);
define('ZOOBOXI_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('ZOOBOXI_PLUGIN_URL', plugin_dir_url(__FILE__));
define('ZOOBOXI_PLUGIN_BASENAME', plugin_basename(__FILE__));

// Autoloader
spl_autoload_register(function ($class) {
    $prefix = 'Zooboxi_';
    if (strpos($class, $prefix) !== 0) return;
    
    $file = str_replace($prefix, '', $class);
    $file = 'class-zooboxi-' . strtolower(str_replace('_', '-', $file)) . '.php';
    
    $dirs = ['includes', 'includes/core', 'includes/sync', 'includes/shipping', 
             'includes/admin', 'includes/frontend', 'includes/api'];
    
    foreach ($dirs as $dir) {
        $path = ZOOBOXI_PLUGIN_DIR . $dir . '/' . $file;
        if (file_exists($path)) {
            require_once $path;
            return;
        }
    }
});

// Check WooCommerce dependency
add_action('plugins_loaded', function() {
    if (!class_exists('WooCommerce')) {
        add_action('admin_notices', function() {
            echo '<div class="error"><p>';
            echo __('Zooboxi Multi-Warehouse requires WooCommerce to be installed and active.', 'zooboxi');
            echo '</p></div>';
        });
        return;
    }
    
    // Initialize plugin
    Zooboxi_Plugin::instance();
});

// Activation/Deactivation hooks
register_activation_hook(__FILE__, ['Zooboxi_Activator', 'activate']);
register_deactivation_hook(__FILE__, ['Zooboxi_Deactivator', 'deactivate']);

// Declare HPOS compatibility
add_action('before_woocommerce_init', function() {
    if (class_exists(\Automattic\WooCommerce\Utilities\FeaturesUtil::class)) {
        \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility(
            'custom_order_tables', __FILE__, true
        );
    }
});
```

---

## Core Classes

### Zooboxi_Plugin (Singleton)

```php
class Zooboxi_Plugin {
    
    private static $instance = null;
    
    public static function instance() {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    private function __construct() {
        $this->load_dependencies();
        $this->register_hooks();
        $this->register_shipping_methods();
        $this->register_rest_api();
        $this->register_cron_events();
    }
    
    private function load_dependencies() {
        // Core
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-warehouse-manager.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-stock-manager.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-delivery-engine.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-location-detector.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-geo-helper.php';
        
        // Sync
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/sync/class-zooboxi-sync-engine.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/sync/class-zooboxi-logger.php';
        
        // Admin
        if (is_admin()) {
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-admin.php';
        }
        
        // Frontend
        if (!is_admin()) {
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-location-popup.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-delivery-badge.php';
        }
    }
    
    private function register_hooks() {
        // Enqueue assets
        add_action('wp_enqueue_scripts', [$this, 'enqueue_frontend_assets']);
        add_action('admin_enqueue_scripts', [$this, 'enqueue_admin_assets']);
        
        // WooCommerce hooks
        add_action('woocommerce_checkout_order_processed', [$this, 'on_order_created'], 10, 3);
        add_action('woocommerce_before_single_product', [$this, 'show_delivery_info']);
        add_action('woocommerce_before_shop_loop_item_title', [$this, 'show_delivery_badge']);
        
        // AJAX
        add_action('wp_ajax_zooboxi_detect_warehouse', [$this, 'ajax_detect_warehouse']);
        add_action('wp_ajax_nopriv_zooboxi_detect_warehouse', [$this, 'ajax_detect_warehouse']);
        add_action('wp_ajax_zooboxi_set_city', [$this, 'ajax_set_city']);
        add_action('wp_ajax_nopriv_zooboxi_set_city', [$this, 'ajax_set_city']);
    }
    
    private function register_shipping_methods() {
        add_filter('woocommerce_shipping_methods', function($methods) {
            $methods['zooboxi_express'] = 'Zooboxi_Express_Shipping';
            $methods['zooboxi_standard'] = 'Zooboxi_Standard_Shipping';
            $methods['zooboxi_shipping'] = 'Zooboxi_National_Shipping';
            $methods['zooboxi_pickup'] = 'Zooboxi_Pickup_Shipping';
            return $methods;
        });
    }
    
    private function register_rest_api() {
        add_action('rest_api_init', function() {
            $controller = new Zooboxi_Rest_Controller();
            $controller->register_routes();
        });
    }
    
    private function register_cron_events() {
        // Custom intervals
        add_filter('cron_schedules', function($schedules) {
            $schedules['zooboxi_5_minutes'] = [
                'interval' => 300,
                'display' => 'Every 5 Minutes (Zooboxi Stock Sync)'
            ];
            $schedules['zooboxi_30_minutes'] = [
                'interval' => 1800,
                'display' => 'Every 30 Minutes (Zooboxi Price Sync)'
            ];
            return $schedules;
        });
        
        // Schedule events
        add_action('zooboxi_sync_stock', [Zooboxi_Sync_Engine::class, 'syncStock']);
        add_action('zooboxi_sync_prices', [Zooboxi_Sync_Engine::class, 'syncPrices']);
        add_action('zooboxi_sync_products', [Zooboxi_Sync_Engine::class, 'syncProducts']);
    }
}
```

---

## REST API Endpoints (WordPress)

```php
class Zooboxi_Rest_Controller extends WP_REST_Controller {
    
    protected $namespace = 'zooboxi/v1';
    
    public function register_routes() {
        // تحديد المستودع بناءً على الموقع
        register_rest_route($this->namespace, '/detect-warehouse', [
            'methods' => 'POST',
            'callback' => [$this, 'detect_warehouse'],
            'permission_callback' => '__return_true', // عام
            'args' => [
                'lat' => ['required' => true, 'type' => 'number'],
                'lng' => ['required' => true, 'type' => 'number'],
            ],
        ]);
        
        // الحصول على خيارات التوصيل
        register_rest_route($this->namespace, '/delivery-options', [
            'methods' => 'POST',
            'callback' => [$this, 'get_delivery_options'],
            'permission_callback' => '__return_true',
        ]);
        
        // قائمة الفروع
        register_rest_route($this->namespace, '/pickup-locations', [
            'methods' => 'GET',
            'callback' => [$this, 'get_pickup_locations'],
            'permission_callback' => '__return_true',
        ]);
        
        // مزامنة يدوية (Admin فقط)
        register_rest_route($this->namespace, '/sync/(?P<type>[a-z]+)', [
            'methods' => 'POST',
            'callback' => [$this, 'trigger_sync'],
            'permission_callback' => function() {
                return current_user_can('manage_woocommerce');
            },
        ]);
    }
    
    public function detect_warehouse($request) {
        $lat = $request->get_param('lat');
        $lng = $request->get_param('lng');
        
        $engine = new Zooboxi_Delivery_Engine();
        $result = $engine->detectDeliveryOptions($lat, $lng);
        
        // حفظ في Session
        WC()->session->set('zooboxi_customer_lat', $lat);
        WC()->session->set('zooboxi_customer_lng', $lng);
        WC()->session->set('zooboxi_delivery_data', $result);
        
        return rest_ensure_response($result);
    }
}
```

---

## لوحة التحكم (Admin)

### قائمة البلقن في WordPress Admin:

```
Zooboxi
├── لوحة التحكم         # نظرة عامة وإحصائيات
├── المستودعات          # إدارة المستودعات وإعداداتها
├── المزامنة            # حالة المزامنة وسجلات
├── الطلبات             # طلبات Zooboxi مع حالة التوصيل
├── إعدادات التوصيل     # رسوم وقواعد التوصيل
└── الإعدادات           # إعدادات API والاتصال
```

### صفحة الإعدادات:

```php
class Zooboxi_Settings_Page {
    
    public function render() {
        $options = [
            'zooboxi_api_url' => [
                'label' => 'sapconnect API URL',
                'type' => 'url',
                'default' => 'https://sapapi.muntajat.sa/api/woo',
            ],
            'zooboxi_api_token' => [
                'label' => 'API Token',
                'type' => 'password',
            ],
            'zooboxi_express_fee' => [
                'label' => 'رسوم التوصيل السريع (ر.س)',
                'type' => 'number',
                'default' => 15,
            ],
            'zooboxi_standard_fee' => [
                'label' => 'رسوم التوصيل العادي (ر.س)',
                'type' => 'number',
                'default' => 10,
            ],
            'zooboxi_shipping_fee' => [
                'label' => 'رسوم الشحن (ر.س)',
                'type' => 'number',
                'default' => 25,
            ],
            'zooboxi_free_shipping_min' => [
                'label' => 'حد الشحن المجاني (ر.س)',
                'type' => 'number',
                'default' => 200,
            ],
            'zooboxi_stock_sync_interval' => [
                'label' => 'فترة مزامنة المخزون (دقائق)',
                'type' => 'number',
                'default' => 5,
            ],
            'zooboxi_default_price_list' => [
                'label' => 'قائمة الأسعار الافتراضية',
                'type' => 'number',
                'default' => 1,
            ],
        ];
        
        // Render settings form...
    }
}
```

---

## قاعدة بيانات البلقن (WordPress tables)

### عند التفعيل:

```php
class Zooboxi_Activator {
    
    public static function activate() {
        global $wpdb;
        
        $charset_collate = $wpdb->get_charset_collate();
        
        // جدول المستودعات
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
            is_central TINYINT(1) DEFAULT 0,
            is_main_hub TINYINT(1) DEFAULT 0,
            is_pickup_enabled TINYINT(1) DEFAULT 1,
            is_active TINYINT(1) DEFAULT 1,
            working_hours JSON,
            phone VARCHAR(20),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) {$charset_collate};";
        
        // جدول سجلات المزامنة
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
        ) {$charset_collate};";
        
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql_warehouses);
        dbDelta($sql_sync_logs);
        
        // جدولة Cron
        if (!wp_next_scheduled('zooboxi_sync_stock')) {
            wp_schedule_event(time(), 'zooboxi_5_minutes', 'zooboxi_sync_stock');
        }
        if (!wp_next_scheduled('zooboxi_sync_products')) {
            wp_schedule_event(time(), 'hourly', 'zooboxi_sync_products');
        }
        if (!wp_next_scheduled('zooboxi_sync_prices')) {
            wp_schedule_event(time(), 'zooboxi_30_minutes', 'zooboxi_sync_prices');
        }
        
        // حفظ رقم الإصدار
        update_option('zooboxi_version', ZOOBOXI_VERSION);
    }
}
```

---

## HPOS (High-Performance Order Storage)

البلقن يدعم **WooCommerce HPOS** (Custom Order Tables) الحديث:

```php
// في الملف الرئيسي
add_action('before_woocommerce_init', function() {
    if (class_exists(\Automattic\WooCommerce\Utilities\FeaturesUtil::class)) {
        \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility(
            'custom_order_tables', ZOOBOXI_PLUGIN_FILE, true
        );
    }
});
```

---

## Hooks المتاحة للمطورين

```php
// Filters
apply_filters('zooboxi_express_radius', $radius, $warehouse);
apply_filters('zooboxi_delivery_fee', $fee, $delivery_type, $distance);
apply_filters('zooboxi_sync_products_args', $args);
apply_filters('zooboxi_product_data', $data, $sapconnect_product);

// Actions
do_action('zooboxi_before_sync', $sync_type);
do_action('zooboxi_after_sync', $sync_type, $results);
do_action('zooboxi_order_synced', $order_id, $sap_doc_entry);
do_action('zooboxi_warehouse_selected', $warehouse_code, $customer_lat, $customer_lng);
do_action('zooboxi_delivery_calculated', $delivery_data);
```
