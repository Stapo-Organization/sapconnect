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
        // i18n (must load before frontend)
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/class-zooboxi-i18n.php';

        // Core
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-geo-helper.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-warehouse-manager.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-stock-manager.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-delivery-engine.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-location-detector.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-order-statuses.php';

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
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-stock-dashboard.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-express-zones-admin.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/admin/class-zooboxi-order-admin.php';
        }

        // Frontend
        if (!is_admin() || wp_doing_ajax()) {
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-location-popup.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-delivery-badge.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-checkout-customizer.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-cart-delivery.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-sku-search.php';
        }

        // API
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/class-zooboxi-rest-controller.php';

        // Intelligence (ranking/clearance/recommendations/events from sapconnect)
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/intelligence/class-zooboxi-intelligence.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/intelligence/class-zooboxi-campaigns.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-dynamic-badges.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-smart-shipments.php';

        // Dynamic homepage (shell shortcode + product rail + per-customer feed).
        // Loaded unconditionally: the rail/feed are needed in the REST context, and
        // the buy-again cache buster hooks order changes that fire in admin/cron too.
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/homepage/class-zooboxi-product-rail.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/homepage/class-zooboxi-hero-slider.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/homepage/class-zooboxi-home-feed.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/homepage/class-zooboxi-homepage.php';

        // Brand boutique pages (/brand/<slug>/): backend sync + themed archive takeover.
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/intelligence/class-zooboxi-brand-sync.php';
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/frontend/class-zooboxi-brand-page.php';

        // Pack-size awareness (كرتون × حبة): pieces-per-unit factors from SAP.
        require_once ZOOBOXI_PLUGIN_DIR . 'includes/core/class-zooboxi-units.php';

        // Mobile app API (namespace zooboxi/v2). Purely additive; kill switch:
        // set option `zooboxi_v2_enabled` to anything but 'yes' to unload it entirely.
        if (get_option('zooboxi_v2_enabled', 'yes') === 'yes') {
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-app-tokens.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-bootstrap.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-product-dto.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-auth-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-location-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-catalog-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-feed-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-cart-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-checkout-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-orders-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-account-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-events-controller.php';
            require_once ZOOBOXI_PLUGIN_DIR . 'includes/api/v2/class-zooboxi-v2-meta-controller.php';
        }
    }

    /* ── Hooks ─────────────────────────────────────── */

    private function register_hooks(): void
    {
        // Assets
        add_action('wp_enqueue_scripts', [$this, 'enqueue_frontend_assets']);
        add_action('admin_enqueue_scripts', [$this, 'enqueue_admin_assets']);

        // Kill WordPress's emoji script site-wide. We don't use core emoji, and
        // wp-emoji-release.min.js rewrites Unicode emoji into s.w.org twemoji <img>
        // tags that render blank/broken (it was eating our badge icons). Native
        // emoji still render via the device font; our badges use inline SVG anyway.
        add_action('init', [$this, 'disable_wp_emojis']);

        // WooCommerce order hooks
        add_action('woocommerce_checkout_order_processed', [$this, 'on_order_created'], 10, 3);

        // Custom order status "جاهز للتسليم" (set by the Exhibition Manager app
        // via sapconnect → WC REST once a branch finishes preparing an order).
        (new Zooboxi_Order_Statuses())->register_hooks();

        // AJAX (location detection for guests + logged in)
        add_action('wp_ajax_zooboxi_detect_warehouse', [Zooboxi_Location_Detector::class, 'ajax_detect']);
        add_action('wp_ajax_nopriv_zooboxi_detect_warehouse', [Zooboxi_Location_Detector::class, 'ajax_detect']);
        add_action('wp_ajax_zooboxi_set_city', [Zooboxi_Location_Detector::class, 'ajax_set_city']);
        add_action('wp_ajax_nopriv_zooboxi_set_city', [Zooboxi_Location_Detector::class, 'ajax_set_city']);

        // Admin menu
        if (is_admin()) {
            $admin = new Zooboxi_Admin();
            add_action('admin_menu', [$admin, 'register_menu']);

            // Express Zones admin page
            $expressZones = new Zooboxi_Express_Zones_Admin();
            add_action('admin_menu', function () use ($expressZones) {
                add_submenu_page(
                    'zooboxi',
                    __('مناطق التوصيل السريع', 'zooboxi'),
                    __('⚡ مناطق التوصيل', 'zooboxi'),
                    'manage_woocommerce',
                    'zooboxi-express-zones',
                    [$expressZones, 'render']
                );
            });

            // Product edit — warehouse stock panel in Inventory tab
            add_action('woocommerce_product_options_stock_status', [self::class, 'render_warehouse_stock_panel']);

            // Orders screen — show the fulfilling branch column + detail line
            (new Zooboxi_Order_Admin())->register_hooks();
        }

        // OTP Authentication (works for both admin and frontend AJAX)
        Zooboxi_OTP_Auth::register_hooks();

        // Intelligence: registered unconditionally (cron + admin-ajax beacon need it outside frontend)
        new Zooboxi_Intelligence();
        // Ad campaigns: registered unconditionally (cron + sync-now ajax + hero shortcode)
        new Zooboxi_Campaigns();
        // Brand boutique sync: unconditional (hourly cron + sync-now ajax).
        new Zooboxi_Brand_Sync();
        // Dynamic homepage: registered unconditionally (shortcode on the front page +
        // the buy-again cache buster must hear order-status changes fired in admin/cron).
        new Zooboxi_Homepage();
        // Smart hero slider (front render is static; instance registers the admin panel).
        new Zooboxi_Hero_Slider();

        // Mobile app API (zooboxi/v2) — same kill switch as its requires above.
        if (get_option('zooboxi_v2_enabled', 'yes') === 'yes' && class_exists('Zooboxi_V2_Bootstrap')) {
            new Zooboxi_V2_Bootstrap();
        }

        // Init frontend components
        if (!is_admin()) {
            new Zooboxi_Location_Popup();
            new Zooboxi_Delivery_Badge();
            new Zooboxi_Checkout_Customizer();
            new Zooboxi_Cart_Delivery();
            new Zooboxi_OTP_Popup();
            new Zooboxi_Recently_Viewed();
            new Zooboxi_Brands_Slider();
            new Zooboxi_Brand_Page();
            new Zooboxi_Dynamic_Badges();
            new Zooboxi_Smart_Shipments();
            new Zooboxi_Sku_Search();

            // Filter stock to show only active warehouse quantity
            add_filter('woocommerce_product_get_stock_quantity', [$this, 'filter_stock_for_customer'], 10, 2);
            add_filter('woocommerce_product_variation_get_stock_quantity', [$this, 'filter_stock_for_customer'], 10, 2);
            add_filter('woocommerce_product_get_stock_status', [$this, 'filter_stock_status_for_customer'], 10, 2);
            add_filter('woocommerce_product_variation_get_stock_status', [$this, 'filter_stock_status_for_customer'], 10, 2);

            // Sort products: in-stock first, out-of-stock last
            add_filter('posts_clauses', [$this, 'sort_products_by_stock'], 999, 2);

            // Inject GPS into shipping package hash so WC recalculates when location changes
            add_filter('woocommerce_cart_shipping_packages', [$this, 'inject_gps_into_packages']);

            // Gently cap cart lines to what is actually reachable in the customer's area,
            // BEFORE WooCommerce's own stock check fires — so the customer sees a friendly
            // "we adjusted the quantity" notice instead of a scary red "(N available)" error.
            add_action('woocommerce_cart_loaded_from_session', [$this, 'cap_cart_to_reachable'], 20);
        }
    }

    /**
     * Reduce (or remove) any cart line whose quantity exceeds the stock reachable for the
     * customer's location. Runs once on cart load, before validation, so it pre-empts the
     * raw WooCommerce out-of-stock error. Location-aware via the same filtered stock the
     * rest of the store uses (single source of truth).
     */
    public function cap_cart_to_reachable($cart): void
    {
        if (is_admin() && !wp_doing_ajax()) return;
        if (!($cart instanceof WC_Cart)) {
            $cart = function_exists('WC') ? WC()->cart : null;
        }
        if (!$cart) return;

        // No location → no filtering → nothing to cap.
        if (empty($this->get_customer_warehouses())) return;

        $adjusted = [];
        foreach ($cart->get_cart() as $key => $item) {
            $product = $item['data'] ?? null;
            if (!$product || !$product->managing_stock()) continue;

            $reachable = $product->get_stock_quantity(); // already filtered to the customer's area
            if ($reachable === null) continue;            // unmanaged → skip
            $reachable = (int) $reachable;

            // Stock is counted in PIECES; a pack variation (كرتون = N حبة)
            // consumes N of them per cart unit — cap in whole packs.
            $units = class_exists('Zooboxi_Units') ? Zooboxi_Units::for_cart_item($item) : 1;

            // The cap must agree with what checkout can actually deliver: the
            // fulfilment resolver spans every reachable tier (express + city +
            // national, split shipments included), while the session-warehouse
            // pool above can be just the express branch. Whenever coordinates
            // exist, the resolver's total is the truth; the narrow pool stays
            // the fallback for a customer with no location yet.
            $qty = (int) ($item['quantity'] ?? 0);
            if (class_exists('Zooboxi_Fulfillment')) {
                [$cust_lat, $cust_lng] = array_pad(array_values(Zooboxi_Fulfillment::customer_location()), 2, 0.0);
                if ($cust_lat && $cust_lng) {
                    $plan      = Zooboxi_Fulfillment::resolve((int) ($item['product_id'] ?? 0), max(1, $qty) * $units, (float) $cust_lat, (float) $cust_lng);
                    $reachable = (int) ($plan['reachable_total'] ?? $reachable);
                }
            }

            $max_units = Zooboxi_Units::units_from_pieces($reachable, $units);

            if ($qty <= $max_units) continue;

            try {
                if ($max_units <= 0) {
                    $cart->remove_cart_item($key);
                    $adjusted[] = [$product->get_name(), 0];
                } else {
                    $cart->set_quantity($key, $max_units, false);
                    $adjusted[] = [$product->get_name(), $max_units];
                }
            } catch (\Throwable $e) {
                // never break the cart over a cap adjustment
            }
        }

        if (!empty($adjusted) && function_exists('wc_add_notice')) {
            foreach ($adjusted as [$name, $n]) {
                if ($n > 0) {
                    wc_add_notice(sprintf(
                        __('عدّلنا كمية «%1$s» إلى %2$d — هذا أقصى المتاح للتوصيل في منطقتك حالياً.', 'zooboxi'),
                        $name, $n
                    ), 'notice');
                } else {
                    wc_add_notice(sprintf(
                        __('أزلنا «%s» من السلة — غير متوفر للتوصيل في منطقتك حالياً.', 'zooboxi'),
                        $name
                    ), 'error');
                }
            }
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

        // Delivery system styles (badges, cart grouping, etc.)
        wp_enqueue_style(
            'zooboxi-delivery',
            ZOOBOXI_PLUGIN_URL . 'public/css/zooboxi-delivery.css',
            ['zooboxi-public'],
            ZOOBOXI_VERSION
        );

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

    /**
     * Disable WordPress's core emoji handling everywhere (front + admin + feeds + mail).
     * Removes the detection script (wp-emoji-release.min.js) that swaps Unicode emoji
     * for s.w.org twemoji <img> tags, plus the related styles, content filters, TinyMCE
     * plugin and DNS prefetch. Native emoji keep rendering via the device font.
     */
    public function disable_wp_emojis(): void
    {
        remove_action('wp_head', 'print_emoji_detection_script', 7);
        remove_action('admin_print_scripts', 'print_emoji_detection_script');
        remove_action('wp_print_styles', 'print_emoji_styles');
        remove_action('admin_print_styles', 'print_emoji_styles');
        remove_filter('the_content_feed', 'wp_staticize_emoji');
        remove_filter('comment_text_rss', 'wp_staticize_emoji');
        remove_filter('wp_mail', 'wp_staticize_emoji_for_email');

        // Drop the emoji plugin from the TinyMCE editor.
        add_filter('tiny_mce_plugins', static function ($plugins) {
            return is_array($plugins) ? array_diff($plugins, ['wpemoji']) : [];
        });

        // Remove the s.w.org emoji DNS-prefetch hint.
        add_filter('wp_resource_hints', static function ($urls, $relation_type) {
            if ('dns-prefetch' === $relation_type) {
                $emoji_url = apply_filters('emoji_svg_url', 'https://s.w.org/images/core/emoji/');
                $urls = array_filter($urls, static function ($url) use ($emoji_url) {
                    return !is_string($url) || strpos($url, $emoji_url) === false;
                });
            }
            return $urls;
        }, 10, 2);
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

        // Express Zones page — Google Maps
        if (strpos($hook, 'zooboxi-express-zones') !== false) {
            // Our script first (defines initZoboxiMap callback)
            wp_enqueue_script(
                'zooboxi-express-zones',
                ZOOBOXI_PLUGIN_URL . 'admin/js/zooboxi-express-zones.js',
                ['jquery'],
                ZOOBOXI_VERSION,
                true
            );
            // Google Maps JS API with Drawing library (loaded after, calls initZoboxiMap)
            $gmaps_key = get_option('zooboxi_google_maps_key', 'AIzaSyCnBLxmrKc270qp_M7885flldbkSPJ3o4k');
            wp_enqueue_script(
                'google-maps-api',
                "https://maps.googleapis.com/maps/api/js?key={$gmaps_key}&libraries=drawing&language=ar&callback=initZoboxiMap",
                ['zooboxi-express-zones'],
                null,
                true
            );
        }
    }

    /* ── Product Sort: In-stock first ────────────── */

    /**
     * Sort WooCommerce product queries: products with stock in customer's
     * relevant warehouses first, out-of-stock/no-data last.
     */
    public function sort_products_by_stock(array $clauses, \WP_Query $query): array
    {
        global $wpdb;

        // Only apply to main product queries on frontend. The mobile API's listing
        // endpoint opts in explicitly via the `zooboxi_v2_listing` flag so the app gets
        // the same in-stock-first order; no web query ever sets that flag.
        if (is_admin() || (!$query->is_main_query() && !$query->get('zooboxi_v2_listing'))) return $clauses;

        // Check if this is a product query (shop, category, tag, brand, search)
        $pt = $query->get('post_type');
        $is_product = ($pt === 'product' || (is_array($pt) && in_array('product', $pt)));
        if (!$is_product && !$query->is_tax('product_cat') && !$query->is_tax('product_tag') && !$query->is_tax('product_brand') && !$query->is_search()) {
            return $clauses;
        }

        $warehouses = $this->get_customer_warehouses();

        // Join the stock status meta key
        $clauses['join'] .= " LEFT JOIN {$wpdb->postmeta} AS zbx_stock_status 
            ON ({$wpdb->posts}.ID = zbx_stock_status.post_id AND zbx_stock_status.meta_key = '_stock_status')";

        // Join the warehouse stock JSON meta
        $clauses['join'] .= " LEFT JOIN {$wpdb->postmeta} AS zbx_wh_stock 
            ON ({$wpdb->posts}.ID = zbx_wh_stock.post_id AND zbx_wh_stock.meta_key = '_zooboxi_warehouse_stock')";

        $original_orderby = $clauses['orderby'] ?: "{$wpdb->posts}.menu_order ASC, {$wpdb->posts}.post_date DESC";

        if (!empty($warehouses)) {
            // Build SQL: check if JSON contains any customer warehouse code
            // JSON format: [{"warehouse_code":"RUH003","in_stock":50},...]
            $locate_parts = [];
            foreach ($warehouses as $code) {
                $esc = esc_sql($code);
                $locate_parts[] = "LOCATE('\"warehouse_code\":\"{$esc}\"', zbx_wh_stock.meta_value) > 0";
            }
            $has_stock_sql = '(' . implode(' OR ', $locate_parts) . ')';

            // Sort: 
            // 1. Put globally instock first (0), outofstock last (1)
            // 2. Put products in customer's warehouses first (0), others last (1)
            $clauses['orderby'] = "CASE WHEN zbx_stock_status.meta_value = 'outofstock' THEN 1 ELSE 0 END ASC, 
                                   CASE WHEN zbx_wh_stock.meta_value IS NOT NULL AND {$has_stock_sql} THEN 0 ELSE 1 END ASC, 
                                   {$original_orderby}";
        } else {
            // No customer location
            // Sort: globally instock first (0), outofstock last (1)
            $clauses['orderby'] = "CASE WHEN zbx_stock_status.meta_value = 'outofstock' THEN 1 ELSE 0 END ASC, 
                                   CASE WHEN zbx_wh_stock.meta_value IS NOT NULL AND zbx_wh_stock.meta_value != '' THEN 0 ELSE 1 END ASC, 
                                   {$original_orderby}";
        }

        return $clauses;
    }

    /* ── GPS Shipping Cache Buster ─────────────────── */

    /**
     * Inject GPS coordinates into shipping packages so WC recalculates
     * shipping rates when the customer's location changes.
     * WC hashes packages to decide whether to call calculate_shipping().
     */
    public function inject_gps_into_packages(array $packages): array
    {
        $lat = '';
        $lng = '';
        $city = '';

        if (function_exists('WC') && WC()->session) {
            $lat = WC()->session->get('zooboxi_customer_lat', '');
            $lng = WC()->session->get('zooboxi_customer_lng', '');
            $city = WC()->session->get('zooboxi_customer_city', '');
        }
        if (empty($lat) && !empty($_COOKIE['zooboxi_lat'])) $lat = $_COOKIE['zooboxi_lat'];
        if (empty($lng) && !empty($_COOKIE['zooboxi_lng'])) $lng = $_COOKIE['zooboxi_lng'];
        if (empty($city) && !empty($_COOKIE['zooboxi_city'])) $city = $_COOKIE['zooboxi_city'];

        foreach ($packages as &$package) {
            $package['zooboxi_lat']  = $lat;
            $package['zooboxi_lng']  = $lng;
            $package['zooboxi_city'] = $city;
        }

        return $packages;
    }

    /* ── Warehouse Stock Filter (Frontend) ───────── */

    /**
     * Determine which warehouse codes are relevant for the current customer.
     *
     * Returns array of warehouse codes the customer can order from:
     *   - Scenario A: Express zone → [express_branch, central_warehouse]
     *   - Scenario B: Same city as central → [central_warehouse]
     *   - Scenario C: No central → [main_hub]
     */
    private function get_customer_warehouses(): array
    {
        // Cache per request
        static $cached = null;
        if ($cached !== null) return $cached;

        $result = [];

        // 1. Get customer location
        $lat = 0.0;
        $lng = 0.0;
        $city = '';
        $delivery_type = '';

        if (function_exists('WC') && WC()->session) {
            $lat = (float) WC()->session->get('zooboxi_customer_lat', 0);
            $lng = (float) WC()->session->get('zooboxi_customer_lng', 0);
            $city = WC()->session->get('zooboxi_customer_city', '');
            $delivery_type = WC()->session->get('zooboxi_delivery_type', '');
        }

        // Fallback to cookies
        if (empty($city) && !empty($_COOKIE['zooboxi_city'])) {
            $city = sanitize_text_field($_COOKIE['zooboxi_city']);
        }
        if (!$lat && !empty($_COOKIE['zooboxi_lat'])) {
            $lat = (float) $_COOKIE['zooboxi_lat'];
        }
        if (!$lng && !empty($_COOKIE['zooboxi_lng'])) {
            $lng = (float) $_COOKIE['zooboxi_lng'];
        }
        if (empty($delivery_type) && !empty($_COOKIE['zooboxi_delivery_type'])) {
            $delivery_type = sanitize_text_field($_COOKIE['zooboxi_delivery_type']);
        }

        // No location at all → no filtering
        if (empty($city) && !$lat) {
            $cached = [];
            return $cached;
        }

        // 2. Check if customer is in express zone (always check if we have coordinates)
        if ($lat && $lng) {
            $expressWarehouses = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
            if (!empty($expressWarehouses)) {
                // Add the express branch
                $result[] = $expressWarehouses[0]['warehouse']['warehouse_code'];
            }
        }

        // 3. Check central warehouse in customer's city
        if (!empty($city)) {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if ($central) {
                $centralCode = $central['warehouse_code'];
                if (!in_array($centralCode, $result, true)) {
                    $result[] = $centralCode;
                }
            }
        }

        // 4. If no warehouses found → fallback to main hub (national shipping)
        if (empty($result)) {
            $hub = Zooboxi_Warehouse_Manager::get_main_hub();
            if ($hub) {
                $result[] = $hub['warehouse_code'];
            }
        }

        $cached = $result;
        return $cached;
    }

    /**
     * Filter product stock quantity — show combined stock from relevant warehouses.
     */
    public function filter_stock_for_customer($quantity, $product)
    {
        static $filtering = false;
        if ($filtering) return $quantity;

        $warehouses = $this->get_customer_warehouses();
        if (empty($warehouses)) return $quantity;

        $filtering = true;

        // For variations, warehouse stock is stored on the parent product
        $product_id = $product->get_id();
        if ($product instanceof WC_Product_Variation) {
            $product_id = $product->get_parent_id();
        }

        $warehouseStock = Zooboxi_Stock_Manager::get_warehouse_stock($product_id);
        $filtering = false;

        if (empty($warehouseStock)) return 0; // SAP is the only source of stock

        // Sum stock across all relevant warehouses
        $totalStock = 0;
        foreach ($warehouseStock as $ws) {
            $code = $ws['warehouse_code'] ?? '';
            if (in_array($code, $warehouses, true)) {
                $totalStock += (int) ($ws['in_stock'] ?? 0);
            }
        }

        return $totalStock;
    }

    /**
     * Filter stock status — product is "instock" if ANY relevant warehouse has it.
     */
    public function filter_stock_status_for_customer($status, $product)
    {
        static $filtering_status = false;
        if ($filtering_status) return $status;

        $warehouses = $this->get_customer_warehouses();
        if (empty($warehouses)) return $status;

        $filtering_status = true;

        // For variations, warehouse stock is stored on the parent product
        $product_id = $product->get_id();
        if ($product instanceof WC_Product_Variation) {
            $product_id = $product->get_parent_id();
        }

        $warehouseStock = Zooboxi_Stock_Manager::get_warehouse_stock($product_id);
        $filtering_status = false;

        if (empty($warehouseStock)) return 'outofstock'; // SAP is the only source of stock

        // If ANY relevant warehouse has stock, product is in stock
        foreach ($warehouseStock as $ws) {
            $code = $ws['warehouse_code'] ?? '';
            if (in_array($code, $warehouses, true) && ((int) ($ws['in_stock'] ?? 0)) > 0) {
                return 'instock';
            }
        }

        return 'outofstock';
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

    /* ── Product Edit — Warehouse Stock Panel ───── */

    public static function render_warehouse_stock_panel(): void
    {
        global $post;
        if (!$post) return;

        $product_id = $post->ID;
        $wh_data = json_decode(get_post_meta($product_id, '_zooboxi_warehouse_stock', true), true);
        $item_code = get_post_meta($product_id, '_zooboxi_item_code', true);
        $total = (float) get_post_meta($product_id, '_stock', true);

        $wh_names = [
            'RUH002' => 'فرع النصر', 'RUH004' => 'فرع الربيع', 'RUH005' => 'فرع قرطبة',
            'RUH006' => 'فرع السليمانية', 'RUH007' => 'فرع الروابي', 'RUH008' => 'فرع السويدي',
            'JED002' => 'فرع جدة', 'DMM001' => 'فرع الدمام', 'MED001' => 'فرع المدينة',
            'ABH001' => 'فرع أبها', 'UZH001' => 'فرع عنيزة',
            'RUH003' => 'شحن الرياض', 'JED001' => 'شحن جدة',
        ];

        ?>
        <div class="options_group" style="border-top:2px solid #0d9488;margin-top:12px;padding-top:16px;">
            <style>
                .zbx-inv-head{display:flex;align-items:center;gap:10px;padding:0 12px 12px;font-size:14px;font-weight:600;color:#0d9488}
                .zbx-inv-head svg{flex-shrink:0}
                .zbx-inv-code{font-size:11px;color:#9ca3af;font-family:monospace;background:#f3f4f6;padding:2px 8px;border-radius:4px;margin-right:8px}
                .zbx-inv-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:8px;padding:0 12px 12px}
                .zbx-inv-item{display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;border:1px solid #e5e7eb;background:#fafbfc;transition:all .15s}
                .zbx-inv-item:hover{border-color:#0d9488;background:#f0fdfa}
                .zbx-inv-item.has-stock{border-right:3px solid #10b981}
                .zbx-inv-item.no-stock{border-right:3px solid #e5e7eb;opacity:.6}
                .zbx-inv-qty{font-size:20px;font-weight:700;min-width:42px;text-align:center;line-height:1}
                .zbx-inv-item.has-stock .zbx-inv-qty{color:#065f46}
                .zbx-inv-item.no-stock .zbx-inv-qty{color:#d1d5db}
                .zbx-inv-info{display:flex;flex-direction:column}
                .zbx-inv-name{font-size:12px;font-weight:600;color:#374151}
                .zbx-inv-wcode{font-size:10px;color:#9ca3af;font-family:monospace}
                .zbx-inv-empty{padding:16px;text-align:center;color:#9ca3af;font-size:13px}
                .zbx-inv-total{display:flex;align-items:center;gap:6px;padding:0 12px 4px;font-size:12px;color:#6b7280}
                .zbx-inv-total strong{color:#0d9488;font-size:14px}
            </style>

            <p class="zbx-inv-head">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
                    <polyline points="3.27 6.96 12 12.01 20.73 6.96"/>
                    <line x1="12" y1="22.08" x2="12" y2="12"/>
                </svg>
                المخزون حسب المستودعات
                <?php if ($item_code): ?>
                <span class="zbx-inv-code"><?php echo esc_html($item_code); ?></span>
                <?php endif; ?>
            </p>

            <?php if (empty($wh_data)): ?>
                <p class="zbx-inv-empty">لا توجد بيانات مخزون من SAP لهذا المنتج</p>
            <?php else: ?>
                <p class="zbx-inv-total">
                    الإجمالي: <strong><?php echo number_format($total); ?></strong> وحدة عبر
                    <strong><?php echo count($wh_data); ?></strong> مستودع
                </p>
                <div class="zbx-inv-grid">
                    <?php
                    // Sort: has stock first, then by qty desc
                    usort($wh_data, function ($a, $b) {
                        return ($b['in_stock'] ?? 0) <=> ($a['in_stock'] ?? 0);
                    });

                    foreach ($wh_data as $wh):
                        $code = $wh['warehouse_code'] ?? '';
                        $qty = (int)($wh['in_stock'] ?? 0);
                        $name = $wh_names[$code] ?? $code;
                        $cls = $qty > 0 ? 'has-stock' : 'no-stock';
                    ?>
                    <div class="zbx-inv-item <?php echo $cls; ?>">
                        <span class="zbx-inv-qty"><?php echo number_format($qty); ?></span>
                        <div class="zbx-inv-info">
                            <span class="zbx-inv-name"><?php echo esc_html($name); ?></span>
                            <span class="zbx-inv-wcode"><?php echo esc_html($code); ?></span>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>
        <?php
    }
}
