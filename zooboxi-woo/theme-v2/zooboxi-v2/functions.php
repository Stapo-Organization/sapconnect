<?php
/**
 * Zooboxi v2 — storefront theme.
 *
 * The theme only draws. Stock, delivery promises, facets, product stories and
 * prices all come from the zooboxi-multi-warehouse plugin (the same layer the
 * app reads), so the website and the app can never tell a customer two
 * different things.
 *
 * Every module guards its plugin calls with class_exists(): with the plugin
 * off, the theme still renders a plain WooCommerce store.
 */

defined('ABSPATH') || exit;

define('ZV_VERSION', '2.0.0');
define('ZV_DIR', get_template_directory());
define('ZV_URI', get_template_directory_uri());

require_once ZV_DIR . '/inc/core.php';       // setup, language, icons, money
require_once ZV_DIR . '/inc/scope.php';      // where the customer is, what reaches them
require_once ZV_DIR . '/inc/catalog.php';    // listings, facets, rails, menu
require_once ZV_DIR . '/inc/assets.php';     // css/js, legacy asset clean-up
require_once ZV_DIR . '/inc/plugin.php';     // detaching the plugin's old web UI
require_once ZV_DIR . '/inc/cart.php';       // mini-cart, fragments, free-delivery meter
require_once ZV_DIR . '/inc/commerce.php';   // ported checkout/cart copy + fixes
require_once ZV_DIR . '/inc/templates.php';  // shared template helpers (card, rail, crumbs)
require_once ZV_DIR . '/inc/webp.php';       // serve uploads as WebP twins when ready

// Customer-account modules carried over from the previous theme (they own
// endpoints, AJAX and templates the app's web views also link to).
require_once ZV_DIR . '/inc/legacy/zbx-account.php';
require_once ZV_DIR . '/inc/legacy/zbx-wishlist.php';
