<?php
/**
 * Assets: one stylesheet, one script, self-hosted fonts.
 * The plugin's old storefront styling is unloaded — the theme draws everything.
 */

defined('ABSPATH') || exit;

function zv_asset_ver(string $rel): string
{
    $f = ZV_DIR . '/' . $rel;
    return file_exists($f) ? (string) filemtime($f) : ZV_VERSION;
}

add_action('wp_enqueue_scripts', static function () {
    wp_enqueue_style('zv-fonts', ZV_URI . '/assets/fonts/fonts.css', [], zv_asset_ver('assets/fonts/fonts.css'));
    wp_enqueue_style('zv', ZV_URI . '/assets/css/zv.css', ['zv-fonts'], zv_asset_ver('assets/css/zv.css'));
    // Modules written for the previous theme declare 'zooboxi-child' as their parent sheet.
    wp_register_style('zooboxi-child', false, ['zv'], ZV_VERSION);

    wp_enqueue_script('jquery');
    wp_enqueue_script('wc-cart-fragments');
    wp_enqueue_script('zv', ZV_URI . '/assets/js/zv.js', ['jquery'], zv_asset_ver('assets/js/zv.js'), true);
    wp_enqueue_script('zv-motion', ZV_URI . '/assets/js/zv-motion.js', ['zv'], zv_asset_ver('assets/js/zv-motion.js'), true);
    wp_localize_script('zv-motion', 'ZVM_FX', ['heart' => zv_img('fx-heart.webp'), 'star' => zv_img('fx-star.webp')]);

    $s = Zv_Scope::get();
    wp_localize_script('zv', 'ZV', [
        'lang'        => zv_lang(),
        'wcAjax'      => class_exists('WC_AJAX') ? WC_AJAX::get_endpoint('%%endpoint%%') : '',
        'ajaxUrl'     => admin_url('admin-ajax.php'),
        'rest'        => esc_url_raw(rest_url()),
        'restNonce'   => wp_create_nonce('wp_rest'),
        'cartUrl'     => function_exists('wc_get_cart_url') ? wc_get_cart_url() : '/cart/',
        'noImage'     => zv_img('cat-sleep.webp'),
        'checkoutUrl' => function_exists('wc_get_checkout_url') ? wc_get_checkout_url() : '/checkout/',
        'mapsKey'     => (string) get_option('zooboxi_google_maps_api_key', ''),
        'located'     => $s['located'],
        'lat'         => Zv_Scope::latlng()[0],
        'lng'         => Zv_Scope::latlng()[1],
        'i18n'        => [
            'added'      => zv_t('أُضيف إلى سلتك', 'Added to your cart'),
            'viewCart'   => zv_t('السلة', 'Cart'),
            'error'      => zv_t('تعذّر ذلك، حاول مرة أخرى', 'Something went wrong, try again'),
            'noResults'  => zv_t('لا نتائج مطابقة', 'No matches'),
            'allResults' => zv_t('عرض كل النتائج', 'See all results'),
            'locating'   => zv_t('جارٍ تحديد موقعك…', 'Finding you…'),
            'confirm'    => zv_t('تأكيد الموقع', 'Confirm location'),
            'saving'     => zv_t('جارٍ الحفظ…', 'Saving…'),
            'gpsDenied'  => zv_t('لم نتمكن من الوصول لموقعك — حرّك الخريطة يدوياً', 'We could not get your location — move the map instead'),
            'outOfZone'  => zv_t('خارج نطاق التوصيل', 'Outside delivery area'),
        ],
    ]);

    // The plugin's own scripts read `zooboxiData` (OTP sign-in, checkout map).
    wp_localize_script('zv', 'zooboxiData', [
        'ajaxUrl' => admin_url('admin-ajax.php'),
        'restUrl' => rest_url('zooboxi/v1/'),
        'nonce'   => wp_create_nonce('zooboxi_nonce'),
        'i18n'    => [
            'detectingLocation' => 'جاري تحديد موقعك...',
            'locationDetected'  => 'تم تحديد موقعك',
            'locationError'     => 'تعذر تحديد الموقع',
            'selectCity'        => 'اختر مدينتك',
            'expressDelivery'   => 'إكسبريس',
            'standardDelivery'  => 'توصيل عادي',
            'nationalShipping'  => 'شحن',
        ],
    ]);

    if (function_exists('is_checkout') && is_checkout()) {
        wp_enqueue_script('zooboxi-checkout', ZV_URI . '/js/zbx-checkout.js', ['jquery'], zv_asset_ver('js/zbx-checkout.js'), true);
        wp_enqueue_script('zooboxi-delight', ZV_URI . '/js/zbx-delight.js', ['jquery'], zv_asset_ver('js/zbx-delight.js'), true);
        if (function_exists('zooboxi_city_ar_map')) {
            wp_localize_script('zooboxi-delight', 'zbxCityMap', zooboxi_city_ar_map());
        }
    }
}, 20);

/** Unload what the new theme replaces (late, after everyone has enqueued). */
add_action('wp_enqueue_scripts', static function () {
    foreach (['zooboxi-public', 'zooboxi-rtl', 'zooboxi-delivery', 'zooboxi-home', 'zooboxi-story', 'classic-theme-styles', 'global-styles'] as $h) {
        wp_dequeue_style($h);
    }
    // The old location script opened a modal on every first visit; the theme asks politely instead.
    wp_dequeue_script('zooboxi-location');
    wp_dequeue_script('zooboxi-delivery');
}, 100);

/** Block styles stay only where a page is actually built from WooCommerce blocks. */
add_filter('style_loader_tag', static function ($tag, $handle) {
    if (!in_array($handle, ['wc-blocks-style', 'wc-blocks-vendors-style'], true)) {
        return $tag;
    }
    $post = is_singular() ? get_post() : null;
    if ($post && (has_block('woocommerce/checkout', $post) || has_block('woocommerce/cart', $post))) {
        return $tag;
    }
    return '';
}, 10, 2);

/** Font preloads for the two faces every page uses first. */
add_action('wp_head', static function () {
    foreach (['Tajawal-500-arabic.woff2', 'BalooBhaijaan2-700-arabic.woff2'] as $f) {
        echo '<link rel="preload" href="' . esc_url(ZV_URI . '/assets/fonts/' . $f) . '" as="font" type="font/woff2" crossorigin>' . "\n";
    }
    echo '<meta name="theme-color" content="#297978">' . "\n";
}, 1);

/** No emoji script, no block-library CSS on a storefront that draws its own UI. */
add_action('init', static function () {
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('wp_print_styles', 'print_emoji_styles');
});
add_action('wp_enqueue_scripts', static function () {
    if (!is_singular('post')) {
        wp_dequeue_style('wp-block-library');
        wp_dequeue_style('wp-block-library-theme');
        wp_dequeue_style('wc-block-style');
    }
}, 100);
