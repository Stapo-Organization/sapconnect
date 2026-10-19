<?php
/**
 * Cart surface: header count, the side drawer, the free-delivery meter and a
 * quantity endpoint. Adding to cart uses WooCommerce's own ?wc-ajax=add_to_cart
 * (it accepts a variation id as product_id), so every tracking pixel that
 * listens for `added_to_cart` keeps working.
 */

defined('ABSPATH') || exit;

/**
 * The tier a cart line will actually travel in — planned exactly as the plugin's
 * Smart Shipments plans it (and so charges it): the chosen size's stock, packs in
 * pieces, and the basket's own storefront. A زوبكسي basket never travels express,
 * however close a branch is, so it must not be labelled or metered as express.
 */
function zv_item_tier(array $item, float $lat, float $lng): string
{
    $pid = (int) ($item['product_id'] ?? 0);
    if (!$pid || !class_exists('Zooboxi_Fulfillment')) {
        return 'all';
    }
    $stock_id = (int) ($item['variation_id'] ?? 0) ?: $pid;
    $units = class_exists('Zooboxi_Units') ? max(1, (int) Zooboxi_Units::for_cart_item($item)) : 1;
    $shelf = class_exists('Zooboxi_Cart_Shelf') ? Zooboxi_Cart_Shelf::current() : '';
    $plan = Zooboxi_Fulfillment::resolve($stock_id, max(1, (int) ($item['quantity'] ?? 1)) * $units, $lat, $lng, null, $shelf);
    return (string) ($plan['slowest'] ?? 'shipping');
}

/**
 * How far the basket is from free delivery, in shelf prices.
 *
 * The plugin waives the fee at `zooboxi_express_free_min` for an all-express
 * basket and at `zooboxi_free_shipping_min` for the whole order otherwise.
 * Until the plugin compares VAT-inclusive totals (filter below), its threshold
 * is ex-VAT — the meter converts so the number a customer reads is the number
 * the checkout will honour.
 *
 * @return array{target:float, remaining:float, pct:int, done:bool, express:bool}|null
 */
function zv_free_progress(): ?array
{
    if (!function_exists('WC') || !WC()->cart || WC()->cart->is_empty()) {
        return null;
    }
    $cart = WC()->cart;
    $s = Zv_Scope::get();

    $all_express = false;
    if ($s['express_open'] && class_exists('Zooboxi_Fulfillment')) {
        [$lat, $lng] = Zv_Scope::latlng();
        $all_express = true;
        foreach ($cart->get_cart() as $item) {
            if (zv_item_tier($item, (float) $lat, (float) $lng) !== 'express') {
                $all_express = false;
                break;
            }
        }
    }
    $min = $all_express && class_exists('Zooboxi_Delivery_Engine')
        ? Zooboxi_Delivery_Engine::express_free_min()
        : Zv_Scope::free_min_standard();
    if ($min <= 0) {
        return null;
    }

    $inclusive = zv_free_inclusive();
    $net   = (float) $cart->get_subtotal();
    $gross = $net + (float) $cart->get_subtotal_tax();
    $basis = $inclusive ? $gross : $net;
    $ratio = ($net > 0 && !$inclusive) ? $gross / $net : 1.0;

    $target    = $min * $ratio;              // in shelf (VAT-inclusive) prices
    $remaining = max(0.0, ($min - $basis) * $ratio);

    return [
        'target'    => $target,
        'remaining' => $remaining,
        'pct'       => (int) max(4, min(100, round($basis / $min * 100))),
        'done'      => $remaining <= 0.009,
        'express'   => $all_express,
    ];
}

/** The free-delivery line shared by the drawer and the cart page. */
function zv_free_meter(): string
{
    $p = zv_free_progress();
    if (!$p) {
        return '';
    }
    $text = $p['done']
        ? zv_t('التوصيل مجاني لطلبك', 'Your delivery is free')
        : sprintf(zv_t('أضف %s ويصير التوصيل مجاني', 'Add %s for free delivery'), zv_money($p['remaining']));
    $pct = max(0, min(100, (int) $p['pct']));
    return '<div class="zv-meter' . ($p['done'] ? ' is-done' : '') . '" data-zv-meter="' . ($p['done'] ? 'done' : 'open') . '" style="--p:' . $pct . '%">'
        . '<div class="zv-meter__text">'
        . ($p['done'] ? '<img class="zv-meter__party" src="' . esc_url(zv_img('mini-cat-celebrate.webp')) . '" alt="" width="40" height="62">' : zv_icon('truck', 18))
        . '<span>' . wp_kses_post($text) . '</span></div>'
        . '<div class="zv-meter__bar" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' . $pct . '"><span style="width:' . $pct . '%"></span>'
        . ($p['done'] ? '' : '<i class="zv-meter__run" aria-hidden="true"><img src="' . esc_url(zv_img('run-dog.webp')) . '" alt="" width="40" height="27"></i>')
        . '</div></div>';
}

/** The drawer body (also the fragment that refreshes it). */
function zv_minicart_body(): string
{
    ob_start();
    echo '<div class="zv-mc__body">';
    if (!function_exists('WC') || !WC()->cart || WC()->cart->is_empty()) {
        echo '<div class="zv-empty">'
            . zv_sleeper('cat-sleep.webp', 150)
            . '<strong>' . esc_html(zv_t('سلتك فاضية', 'Your cart is empty')) . '</strong>'
            . '<span>' . esc_html(zv_t('أليفك ينتظر شيئاً لذيذاً', 'Your pet is waiting for something tasty')) . '</span>'
            . '<a class="zv-btn zv-btn--primary" href="' . esc_url(home_url('/')) . '">' . esc_html(zv_t('ابدأ التسوّق', 'Start shopping')) . '</a>'
            . '</div></div>';
        return (string) ob_get_clean();
    }
    $cart = WC()->cart;
    echo zv_free_meter(); // phpcs:ignore
    echo '<ul class="zv-mc__list">';
    foreach ($cart->get_cart() as $key => $item) {
        $p = $item['data'] ?? null;
        if (!$p instanceof WC_Product || !$p->exists() || $item['quantity'] <= 0) {
            continue;
        }
        $parent = $p->get_parent_id() ? wc_get_product($p->get_parent_id()) : $p;
        $img = wp_get_attachment_image_url($p->get_image_id() ?: ($parent ? $parent->get_image_id() : 0), 'woocommerce_thumbnail');
        if (!$img && class_exists('Zooboxi_Product_DTO')) {
            $img = Zooboxi_Product_DTO::image_url($parent ?: $p, 'woocommerce_thumbnail');
        }
        $name = $parent ? $parent->get_name() : $p->get_name();
        $variant = $p->is_type('variation') ? wc_get_formatted_variation($p, true, false, false) : '';
        $max = $p->get_max_purchase_quantity();
        $line = (float) $item['line_subtotal'] + (float) $item['line_subtotal_tax'];
        echo '<li class="zv-mc__item" data-key="' . esc_attr($key) . '">'
            . '<a class="zv-mc__img" href="' . esc_url($p->get_permalink()) . '"><img src="' . esc_url($img ?: wc_placeholder_img_src()) . '" alt="" loading="lazy" width="72" height="72"></a>'
            . '<div class="zv-mc__info">'
            . '<a class="zv-mc__name" href="' . esc_url($p->get_permalink()) . '">' . esc_html($name) . '</a>'
            . ($variant ? '<span class="zv-mc__var">' . esc_html(wp_strip_all_tags($variant)) . '</span>' : '')
            . '<div class="zv-mc__row">'
            . zv_stepper_html((int) $item['quantity'], $max > 0 ? (int) $max : 99, $key)
            . '<strong class="zv-mc__price">' . zv_money($line) . '</strong>'
            . '</div></div>'
            . '<button type="button" class="zv-mc__remove" data-zv-remove="' . esc_attr($key) . '" aria-label="' . esc_attr(zv_t('إزالة', 'Remove')) . '">' . zv_icon('trash', 18) . '</button>'
            . '</li>';
    }
    echo '</ul>';
    $total = (float) $cart->get_subtotal() + (float) $cart->get_subtotal_tax();
    echo '<div class="zv-mc__foot">'
        . '<div class="zv-mc__sum"><span>' . esc_html(zv_t('المجموع', 'Subtotal')) . '</span><strong>' . zv_money($total) . '</strong></div>'
        . '<p class="zv-mc__note">' . esc_html(zv_t('الأسعار شاملة الضريبة · التوصيل يُحسب عند إتمام الطلب', 'Prices include VAT · delivery is added at checkout')) . '</p>'
        . '<a class="zv-btn zv-btn--primary zv-btn--block" href="' . esc_url(wc_get_checkout_url()) . '">' . esc_html(zv_t('إتمام الطلب', 'Checkout')) . '</a>'
        . '<a class="zv-btn zv-btn--ghost zv-btn--block" href="' . esc_url(wc_get_cart_url()) . '">' . esc_html(zv_t('عرض السلة', 'View cart')) . '</a>'
        . '</div>';
    echo '</div>';
    return (string) ob_get_clean();
}

/** − n + control; with a cart key it edits that line, without it it is a plain picker. */
function zv_stepper_html(int $qty, int $max = 99, string $key = ''): string
{
    $k = $key !== '' ? ' data-key="' . esc_attr($key) . '"' : '';
    return '<div class="zv-step"' . $k . ' data-max="' . (int) $max . '">'
        . '<button type="button" class="zv-step__btn" data-step="1" aria-label="' . esc_attr(zv_t('زيادة', 'More')) . '">' . zv_icon('plus', 16) . '</button>'
        . '<span class="zv-step__n" aria-live="polite">' . (int) $qty . '</span>'
        . '<button type="button" class="zv-step__btn" data-step="-1" aria-label="' . esc_attr(zv_t('إنقاص', 'Less')) . '">' . zv_icon($qty <= 1 && $key !== '' ? 'trash' : 'minus', 16) . '</button>'
        . '</div>';
}

function zv_cart_count(): int
{
    return function_exists('WC') && WC()->cart ? (int) WC()->cart->get_cart_contents_count() : 0;
}

function zv_cart_total(): float
{
    return function_exists('WC') && WC()->cart ? (float) WC()->cart->get_subtotal() + (float) WC()->cart->get_subtotal_tax() : 0.0;
}

/** Product id → {qty, key}: lets every card show its stepper. */
function zv_cart_map(): array
{
    $map = [];
    if (function_exists('WC') && WC()->cart) {
        foreach (WC()->cart->get_cart() as $key => $item) {
            $pid = (int) ($item['variation_id'] ?: $item['product_id']);
            $map[$pid] = ['qty' => (int) $item['quantity'], 'key' => $key];
            if ($item['variation_id']) {
                $map['p' . (int) $item['product_id']] = ($map['p' . (int) $item['product_id']] ?? 0) + (int) $item['quantity'];
            }
        }
    }
    return $map;
}

add_filter('woocommerce_add_to_cart_fragments', static function ($fragments) {
    $n = zv_cart_count();
    $fragments['span.zv-cart-count'] = '<span class="zv-cart-count' . ($n ? '' : ' is-zero') . '">' . $n . '</span>';
    $fragments['span.zv-cart-total'] = '<span class="zv-cart-total">' . ($n ? zv_money(zv_cart_total()) : esc_html(zv_t('السلة', 'Cart'))) . '</span>';
    $fragments['div.zv-mc__body'] = zv_minicart_body();
    $fragments['script#zv-cart-map'] = '<script id="zv-cart-map" type="application/json">' . wp_json_encode((object) zv_cart_map()) . '</script>';
    return $fragments;
});

/** ?wc-ajax=zv_set_qty — key + qty → refreshed fragments. qty 0 removes the line. */
add_action('wc_ajax_zv_set_qty', static function () {
    $key = isset($_POST['key']) ? wc_clean(wp_unslash($_POST['key'])) : '';
    $qty = isset($_POST['qty']) ? max(0, (int) $_POST['qty']) : 0;
    if ($key === '' || !WC()->cart || !WC()->cart->get_cart_item($key)) {
        wp_send_json_error(['message' => 'line not found'], 404);
    }
    if ($qty === 0) {
        WC()->cart->remove_cart_item($key);
    } else {
        $item = WC()->cart->get_cart_item($key);
        $max = $item['data']->get_max_purchase_quantity();
        if ($max > 0 && $qty > $max) {
            $qty = $max;
        }
        WC()->cart->set_quantity($key, $qty, true);
    }
    WC()->cart->calculate_totals();
    WC_AJAX::get_refreshed_fragments();
});

/** «اشترِ الآن» without JavaScript: add, then straight to checkout. */
add_filter('woocommerce_add_to_cart_redirect', static function ($url) {
    return !empty($_REQUEST['zv_buy_now']) ? wc_get_checkout_url() : $url;
});

/** The cart's side column holds the totals; cross-sells would squeeze into it. */
add_action('wp', static function () {
    remove_action('woocommerce_cart_collaterals', 'woocommerce_cross_sell_display');
});
