<?php
/**
 * Plugin Name: Zooboxi — storefront v2 preview switch
 * Description: Serves the new theme (zooboxi-v2) to a browser that opened any page with ?zv2=1, and the current theme to everyone else. ?zv2=0 switches back. Setting the option `zooboxi_v2_live` to "yes" serves v2 to every visitor (a browser can still opt out with ?zv2=0).
 *
 * wp-admin and admin-ajax always run the current theme, so nothing in the dashboard changes.
 * REST requests (the app's API) and WP-Cron also keep the current theme: the app API still calls
 * helpers that only the old theme defines (category icons, per-category filters, filter labels).
 */

defined('ABSPATH') || exit;

if (isset($_GET['zv2']) && !(defined('WP_CLI') && WP_CLI)) {
    $zv2 = $_GET['zv2'] === '1' ? '1' : '0';
    setcookie('zv2', $zv2, [
        'expires'  => time() + 30 * 86400,
        'path'     => '/',
        'secure'   => true,
        'httponly' => false,
        'samesite' => 'Lax',
    ]);
    $_COOKIE['zv2'] = $zv2;
}

/** REST_REQUEST is defined only after the theme loads, so read the URL. */
function zooboxi_v2_is_rest_request(): bool
{
    if (isset($_GET['rest_route'])) {
        return true;
    }
    $prefix = '/' . trim(function_exists('rest_get_url_prefix') ? rest_get_url_prefix() : 'wp-json', '/') . '/';
    return strpos((string) ($_SERVER['REQUEST_URI'] ?? ''), $prefix) !== false;
}

function zooboxi_v2_wanted(): bool
{
    static $wanted = null;
    if ($wanted !== null) {
        return $wanted;
    }
    if ((defined('WP_CLI') && WP_CLI) || is_admin() || !is_dir(WP_CONTENT_DIR . '/themes/zooboxi-v2')) {
        return $wanted = false;
    }
    if ((defined('DOING_CRON') && DOING_CRON) || zooboxi_v2_is_rest_request()) {
        return $wanted = false;
    }
    $c = isset($_COOKIE['zv2']) ? (string) $_COOKIE['zv2'] : '';
    if ($c === '0') {
        return $wanted = false;
    }
    if ($c === '1') {
        return $wanted = true;
    }
    return $wanted = (get_option('zooboxi_v2_live', 'no') === 'yes');
}

foreach (['pre_option_template', 'pre_option_stylesheet'] as $zv2_hook) {
    add_filter($zv2_hook, static function ($value) {
        return zooboxi_v2_wanted() ? 'zooboxi-v2' : $value;
    });
}
unset($zv2_hook);
