<?php
/**
 * Zooboxi — Product card foot (name + price).
 *
 * Fixes the money itself, not just its styling: Saudi number format, a
 * readable "starts from" instead of a two-ended range, and an explicit
 * discount chip so a sale reads at a glance.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

/* ═══════════════════════════════════════════════════════════════════
   1. NUMBER FORMAT
   Prices rendered as "12,00" (European). Saudi Arabia writes 1,234.50 —
   a comma decimal makes a price genuinely ambiguous.
   Display-only: WooCommerce always stores the raw decimal.
   ═══════════════════════════════════════════════════════════════════ */

add_filter('wc_get_price_decimal_separator', static fn() => '.', 20);
add_filter('wc_get_price_thousand_separator', static fn() => ',', 20);

/* ═══════════════════════════════════════════════════════════════════
   2. PRICE HTML
   ═══════════════════════════════════════════════════════════════════ */

/**
 * Variable products: "يبدأ من 72.90 ﷼" instead of "72.90 – 174.15".
 *
 * A range forces the shopper to parse two numbers and, in RTL, to work out
 * which end is which. The floor price is the only figure that helps them
 * decide whether to open the product.
 */
add_filter('woocommerce_get_price_html', function ($html, $product) {
    if (!$product instanceof WC_Product_Variable) {
        return $html;
    }

    $min = $product->get_variation_price('min', true);
    $max = $product->get_variation_price('max', true);

    if ($min === '' || $min === null) {
        return $html;
    }

    $suffix = $product->get_price_suffix();

    if ((float) $min === (float) $max) {
        return wc_price($min) . $suffix;
    }

    return '<span class="zbx-price-from">'
        . '<span class="zbx-from-lbl">يبدأ من</span> '
        . wc_price($min)
        . '</span>' . $suffix;
}, 30, 2);

/** A sale is only persuasive if the shopper can see how much it saves. */
add_filter('woocommerce_get_price_html', function ($html, $product) {
    if (!$product instanceof WC_Product || !$product->is_on_sale()) {
        return $html;
    }

    if ($product instanceof WC_Product_Variable) {
        $regular = (float) $product->get_variation_regular_price('min', true);
        $sale    = (float) $product->get_variation_price('min', true);
    } else {
        $regular = (float) $product->get_regular_price();
        $sale    = (float) $product->get_price();
    }

    if ($regular <= 0 || $sale <= 0 || $sale >= $regular) {
        return $html;
    }

    $off = (int) round((1 - $sale / $regular) * 100);
    if ($off < 5) {
        return $html;                      // rounding noise, not an offer
    }

    return $html . ' <span class="zbx-off" dir="ltr">-' . $off . '%</span>';
}, 40, 2);

/* WooCommerce's own range wording ("… through …") reads wrong in Arabic;
   our rebuild above replaces it, this covers anywhere else it surfaces. */
add_filter('gettext', function ($translated, $original, $domain) {
    if ($domain !== 'woocommerce') {
        return $translated;
    }
    static $map = [
        '%1$s &ndash; %2$s'          => '%1$s – %2$s',
        'Price range: %1$s through %2$s' => 'السعر من %1$s إلى %2$s',
    ];
    return $map[$original] ?? $translated;
}, 20, 3);
