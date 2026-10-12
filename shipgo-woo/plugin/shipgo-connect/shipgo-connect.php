<?php
/**
 * Plugin Name: ShipGo Connect
 * Plugin URI:  https://wms.alofq.sa
 * Description: يربط متجر WooCommerce بنظام ShipGo (WMS/OMS): يرسل الطلبات للمستودع ويحجز الكميات ويعيد تحديث حالة الطلب والتتبّع آليًا. يدعم وضع المراقبة (Sandbox).
 * Version:     1.0.0
 * Author:      Muntajat / PPTCO
 * Author URI:  https://muntajat.sa
 * License:     Proprietary
 * Text Domain: shipgo
 * Domain Path: /languages
 * Requires at least: 6.5
 * WC requires at least: 9.0
 * Requires PHP: 8.1
 */

defined('ABSPATH') || exit;

define('SHIPGO_VERSION', '1.0.0');
define('SHIPGO_PLUGIN_FILE', __FILE__);
define('SHIPGO_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('SHIPGO_PLUGIN_URL', plugin_dir_url(__FILE__));
define('SHIPGO_PLUGIN_BASENAME', plugin_basename(__FILE__));

// PSR-ish autoloader: ShipGo_Foo_Bar → includes[/<sub>]/class-shipgo-foo-bar.php
spl_autoload_register(function ($class) {
    $prefix = 'ShipGo_';
    if (strpos($class, $prefix) !== 0) {
        return;
    }
    $file = 'class-shipgo-' . strtolower(str_replace('_', '-', substr($class, strlen($prefix)))) . '.php';
    $dirs = ['includes', 'includes/core', 'includes/api', 'includes/admin', 'includes/frontend'];
    foreach ($dirs as $dir) {
        $path = SHIPGO_PLUGIN_DIR . $dir . '/' . $file;
        if (file_exists($path)) {
            require_once $path;
            return;
        }
    }
});

// WooCommerce dependency gate
add_action('plugins_loaded', function () {
    if (!class_exists('WooCommerce')) {
        add_action('admin_notices', function () {
            echo '<div class="error"><p>' . esc_html__('يتطلّب ShipGo Connect تفعيل WooCommerce.', 'shipgo') . '</p></div>';
        });
        return;
    }
    ShipGo_Plugin::instance();
});

register_activation_hook(__FILE__, ['ShipGo_Activator', 'activate']);
register_deactivation_hook(__FILE__, ['ShipGo_Deactivator', 'deactivate']);

// HPOS (custom order tables) compatibility
add_action('before_woocommerce_init', function () {
    if (class_exists(\Automattic\WooCommerce\Utilities\FeaturesUtil::class)) {
        \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility('custom_order_tables', __FILE__, true);
    }
});
