<?php
/**
 * Plugin Name: Zooboxi Multi-Warehouse
 * Plugin URI:  https://store.zooboxi.com
 * Description: نظام المستودعات المتعددة والتوصيل الذكي لمتجر Zooboxi
 * Version:     1.0.0
 * Author:      Muntajat / PPTCO
 * Author URI:  https://muntajat.sa
 * License:     Proprietary
 * Text Domain: zooboxi
 * Domain Path: /languages
 * Requires at least: 6.5
 * Tested up to: 7.0
 * WC requires at least: 9.0
 * WC tested up to: 10.8
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

    $dirs = [
        'includes',
        'includes/core',
        'includes/sync',
        'includes/shipping',
        'includes/admin',
        'includes/frontend',
        'includes/api',
        'includes/auth',
    ];

    foreach ($dirs as $dir) {
        $path = ZOOBOXI_PLUGIN_DIR . $dir . '/' . $file;
        if (file_exists($path)) {
            require_once $path;
            return;
        }
    }
});

// Check WooCommerce dependency
add_action('plugins_loaded', function () {
    if (!class_exists('WooCommerce')) {
        add_action('admin_notices', function () {
            echo '<div class="error"><p>';
            echo esc_html__('Zooboxi Multi-Warehouse requires WooCommerce to be installed and active.', 'zooboxi');
            echo '</p></div>';
        });
        return;
    }

    // Initialize plugin
    Zooboxi_Plugin::instance();
});

// Activation / Deactivation hooks
register_activation_hook(__FILE__, ['Zooboxi_Activator', 'activate']);
register_deactivation_hook(__FILE__, ['Zooboxi_Deactivator', 'deactivate']);

// Declare HPOS compatibility
add_action('before_woocommerce_init', function () {
    if (class_exists(\Automattic\WooCommerce\Utilities\FeaturesUtil::class)) {
        \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility(
            'custom_order_tables',
            __FILE__,
            true
        );
    }
});
