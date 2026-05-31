<?php
/**
 * Main Plugin Singleton.
 */
class Zooboxi_Plugin
{
    private static ?self $instance = null;

    public static function instance(): self
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    private function __construct()
    {
        $this->load_dependencies();
        $this->register_hooks();
        $this->register_shipping_methods();
        $this->register_rest_api();
        $this->register_cron_events();
    }

    /* ── Dependencies ──────────────────────────────── */

    private function load_dependencies(): void
    {
        // Core
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-geo-helper.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-warehouse-manager.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-stock-manager.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-delivery-engine.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-location-detector.php';

        // Sync
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/sync/class-zooboxi-logger.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/sync/class-zooboxi-sync-engine.php';

        // Shipping
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/shipping/class-zooboxi-express-shipping.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/shipping/class-zooboxi-standard-shipping.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/shipping/class-zooboxi-national-shipping.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/shipping/class-zooboxi-pickup-shipping.php';

        // Admin
        if (is_admin()) {
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-admin.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-settings-page.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-sync-dashboard.php';
        }

        // Frontend
        if (!is_admin() || wp_doing_ajax()) {
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-location-popup.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-delivery-badge.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-checkout-customizer.php';
        }

        // API
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/class-zooboxi-rest-controller.php';
    }

    /* ── Hooks ─────────────────────────────────────── */

    private function register_hooks(): void
    {
        // Assets
        add_action('wp_enqueue_scripts', [$this, 'enqueue_frontend_assets']);
        add_action('admin_enqueue_scripts', [$this, 'enqueue_admin_assets']);

        // WooCommerce order hooks
        add_action('woocommerce_checkout_order_processed', [$this, 'on_order_created'], 10, 3);

        // AJAX (location detection for guests + logged in)
        add_action('wp_ajax_zooboxi_detect_warehouse', [Zooboxi_Location_Detector::class, 'ajax_detect']);
        add_action('wp_ajax_nopriv_zooboxi_detect_warehouse', [Zooboxi_Location_Detector::class, 'ajax_detect']);
        add_action('wp_ajax_zooboxi_set_city', [Zooboxi_Location_Detector::class, 'ajax_set_city']);
        add_action('wp_ajax_nopriv_zooboxi_set_city', [Zooboxi_Location_Detector::class, 'ajax_set_city']);

        // Admin menu
        if (is_admin()) {
            $admin = new Zooboxi_Admin();
            add_action('admin_menu', [$admin, 'register_menu']);
        }

        // Init frontend components
        if (!is_admin()) {
            new Zooboxi_Location_Popup();
            new Zooboxi_Delivery_Badge();
            new Zooboxi_Checkout_Customizer();
        }
    }

    /* ── Shipping ──────────────────────────────────── */

    private function register_shipping_methods(): void
    {
        add_filter('woocommerce_shipping_methods', function ($methods) {
            $methods['zooboxi_express']  = 'Zooboxi_Express_Shipping';
            $methods['zooboxi_standard'] = 'Zooboxi_Standard_Shipping';
            $methods['zooboxi_shipping'] = 'Zooboxi_National_Shipping';
            $methods['zooboxi_pickup']   = 'Zooboxi_Pickup_Shipping';
            return $methods;
        });
    }

    /* ── REST API ──────────────────────────────────── */

    private function register_rest_api(): void
    {
        add_action('rest_api_init', function () {
            $controller = new Zooboxi_Rest_Controller();
            $controller->register_routes();
        });
    }

    /* ── Cron ──────────────────────────────────────── */

    private function register_cron_events(): void
    {
        // Custom intervals
        add_filter('cron_schedules', function ($schedules) {
            $schedules['zooboxi_5_minutes'] = [
                'interval' => 300,
                'display'  => 'Every 5 Minutes (Zooboxi Stock Sync)',
            ];
            $schedules['zooboxi_30_minutes'] = [
                'interval' => 1800,
                'display'  => 'Every 30 Minutes (Zooboxi Price Sync)',
            ];
            return $schedules;
        });

        // Bind cron actions to sync methods
        add_action('zooboxi_sync_stock', function () {
            $engine = new Zooboxi_Sync_Engine();
            $engine->sync_stock();
        });
        add_action('zooboxi_sync_prices', function () {
            $engine = new Zooboxi_Sync_Engine();
            $engine->sync_prices();
        });
        add_action('zooboxi_sync_products', function () {
            $engine = new Zooboxi_Sync_Engine();
            $engine->sync_products();
        });
    }

    /* ── Asset Enqueueing ─────────────────────────── */

    public function enqueue_frontend_assets(): void
    {
        wp_enqueue_style(
            'zooboxi-public',
            ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-public.css',
            [],
            ZOOBOXI_VERSION
        );

        if (is_rtl()) {
            wp_enqueue_style(
                'zooboxi-rtl',
                ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-rtl.css',
                ['zooboxi-public'],
                ZOOBOXI_VERSION
            );
        }

        wp_enqueue_script(
            'zooboxi-location',
            ZOOBOXI_PLUGIN_URL . 'public/js/zooboxi-location.js',
            ['jquery'],
            ZOOBOXI_VERSION,
            true
        );

        wp_enqueue_script(
            'zooboxi-delivery',
            ZOOBOXI_PLUGIN_URL . 'public/js/zooboxi-delivery.js',
            ['jquery'],
            ZOOBOXI_VERSION,
            true
        );

        wp_localize_script('zooboxi-location', 'zooboxiData', [
            'ajaxUrl'  => admin_url('admin-ajax.php'),
            'restUrl'  => rest_url('zooboxi/v1/'),
            'nonce'    => wp_create_nonce('zooboxi_nonce'),
            'i18n'     => [
                'detectingLocation' => __('جاري تحديد موقعك...', 'zooboxi'),
                'locationDetected'  => __('تم تحديد موقعك', 'zooboxi'),
                'locationError'     => __('تعذر تحديد الموقع', 'zooboxi'),
                'selectCity'        => __('اختر مدينتك', 'zooboxi'),
                'expressDelivery'   => __('توصيل سريع', 'zooboxi'),
                'standardDelivery'  => __('توصيل عادي', 'zooboxi'),
                'nationalShipping'  => __('شحن', 'zooboxi'),
            ],
        ]);
    }

    public function enqueue_admin_assets(string $hook): void
    {
        if (strpos($hook, 'zooboxi') === false) return;

        wp_enqueue_style(
            'zooboxi-admin',
            ZOOBOXI_PLUGIN_URL . 'admin/css/zooboxi-admin.css',
            [],
            ZOOBOXI_VERSION
        );

        wp_enqueue_script(
            'zooboxi-admin',
            ZOOBOXI_PLUGIN_URL . 'admin/js/zooboxi-admin.js',
            ['jquery'],
            ZOOBOXI_VERSION,
            true
        );

        wp_localize_script('zooboxi-admin', 'zooboxiAdmin', [
            'ajaxUrl' => admin_url('admin-ajax.php'),
            'nonce'   => wp_create_nonce('zooboxi_admin_nonce'),
        ]);
    }

    /* ── Order Processing ─────────────────────────── */

    public function on_order_created(int $order_id, array $posted_data, \WC_Order $order): void
    {
        // Save delivery metadata to order
        $session = WC()->session;
        if ($session) {
            $order->update_meta_data('_zooboxi_warehouse', $session->get('zooboxi_warehouse_code', ''));
            $order->update_meta_data('_zooboxi_delivery_type', $session->get('zooboxi_delivery_type', ''));
            $order->update_meta_data('_zooboxi_lat', $session->get('zooboxi_customer_lat', ''));
            $order->update_meta_data('_zooboxi_lng', $session->get('zooboxi_customer_lng', ''));
            $order->save();
        }

        // Push order to sapconnect
        $engine = new Zooboxi_Sync_Engine();
        $engine->push_order($order_id);
    }
}
