<?php
/** Every WooCommerce loop (related, up-sells, shortcodes, the brand boutique) draws the theme's card. */
defined('ABSPATH') || exit;
global $product;
if (empty($product) || !$product->is_visible()) {
    return;
}
zv_loop_card();
