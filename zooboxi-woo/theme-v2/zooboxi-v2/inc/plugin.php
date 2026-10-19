<?php
/**
 * Detach the parts of the plugin's old web UI the theme now draws itself.
 * Data, AJAX, shipping, OTP and checkout behaviour are untouched.
 */

defined('ABSPATH') || exit;

/** Remove every callback on $hook whose object (or class) is $class. */
function zv_detach(string $hook, string $class): void
{
    global $wp_filter;
    if (empty($wp_filter[$hook])) {
        return;
    }
    foreach ($wp_filter[$hook]->callbacks as $priority => $callbacks) {
        foreach ($callbacks as $cb) {
            $fn = $cb['function'];
            $owner = is_array($fn) ? (is_object($fn[0]) ? get_class($fn[0]) : (string) $fn[0]) : '';
            if ($owner === $class) {
                remove_action($hook, $fn, $priority);
            }
        }
    }
}

add_action('wp', static function () {
    // The location modal (it auto-opened on every first visit and asked for GPS on load).
    zv_detach('wp_footer', 'Zooboxi_Location_Popup');
    // Old card badges and the PDP warehouse list (named branches to customers).
    foreach (['woocommerce_before_shop_loop_item_title', 'woocommerce_after_shop_loop_item_title', 'woocommerce_after_shop_loop_item', 'woocommerce_single_product_summary', 'woocommerce_before_add_to_cart_form', 'woocommerce_after_add_to_cart_form', 'wp_footer'] as $hook) {
        zv_detach($hook, 'Zooboxi_Delivery_Badge');
        zv_detach($hook, 'Zooboxi_Dynamic_Badges');
    }
}, 99);

/**
 * Brand boutiques draw inside the theme (woocommerce/archive-product.php +
 * zv_brand_head) from the same published kit, so the plugin's full-bleed
 * template and its sheets stand down. Its small script stays: it reports
 * banner impressions and clicks (data-zb-zone) to the ads spine.
 */
add_action('wp', static function () {
    zv_detach('template_include', 'Zooboxi_Brand_Page');
    zv_detach('wp_head', 'Zooboxi_Brand_Page');
}, 99);
add_action('wp_enqueue_scripts', static function () {
    foreach (['zooboxi-brand', 'zooboxi-brand-fonts'] as $h) {
        wp_dequeue_style($h);
    }
}, 100);

/** The plugin's [zooboxi_home] homepage shell is replaced by front-page.php. */
add_filter('zooboxi_home_enabled', '__return_false');
