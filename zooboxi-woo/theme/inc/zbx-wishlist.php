<?php
/**
 * Zooboxi — Wishlist ("المفضلة")
 *
 * Self-contained: no wishlist plugin is installed. Favourites live in user
 * meta, so they follow the customer across devices.
 *
 * Guests: the heart stashes the intent locally, opens the store's existing
 * phone/OTP modal, and the favourite is saved the moment they're logged in —
 * the OTP plugin's own wishlist interceptor only reloads the page and loses
 * the intent, so we deliberately do not use its selector.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

const ZBX_WISHLIST_META = '_zbx_wishlist';

/* ═══════════════════════════════════════════════════════════════════
   1. STORE
   ═══════════════════════════════════════════════════════════════════ */

function zooboxi_wishlist(int $user_id = 0): array
{
    $user_id = $user_id ?: get_current_user_id();
    if (!$user_id) {
        return [];
    }
    $ids = get_user_meta($user_id, ZBX_WISHLIST_META, true);
    if (!is_array($ids)) {
        return [];
    }
    return array_values(array_unique(array_filter(array_map('intval', $ids))));
}

function zooboxi_wishlist_save(array $ids, int $user_id = 0): void
{
    $user_id = $user_id ?: get_current_user_id();
    if (!$user_id) {
        return;
    }
    $ids = array_values(array_unique(array_filter(array_map('intval', $ids))));
    $ids = array_slice($ids, 0, 200);              // sane ceiling
    update_user_meta($user_id, ZBX_WISHLIST_META, $ids);
}

function zooboxi_wishlist_has(int $product_id, int $user_id = 0): bool
{
    return in_array($product_id, zooboxi_wishlist($user_id), true);
}

function zooboxi_wishlist_count(int $user_id = 0): int
{
    return count(zooboxi_wishlist($user_id));
}

/** @return array{state:string,count:int} */
function zooboxi_wishlist_toggle(int $product_id, int $user_id = 0, ?bool $force = null): array
{
    $user_id = $user_id ?: get_current_user_id();
    $ids     = zooboxi_wishlist($user_id);
    $has     = in_array($product_id, $ids, true);
    $add     = $force ?? !$has;

    if ($add && !$has) {
        array_unshift($ids, $product_id);          // newest first
    } elseif (!$add && $has) {
        $ids = array_values(array_diff($ids, [$product_id]));
    }

    zooboxi_wishlist_save($ids, $user_id);
    return ['state' => $add ? 'added' : 'removed', 'count' => count($ids)];
}

/* ═══════════════════════════════════════════════════════════════════
   2. THE HEART
   ═══════════════════════════════════════════════════════════════════ */

function zooboxi_fav_icon(): string
{
    return '<svg class="zbx-fav__ic" viewBox="0 0 24 24" aria-hidden="true" focusable="false">'
        . '<path d="M12 20.5s-7.5-4.7-9.4-9A5.1 5.1 0 0 1 12 6.2a5.1 5.1 0 0 1 9.4 5.3c-1.9 4.3-9.4 9-9.4 9Z"'
        . ' fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>';
}

function zooboxi_fav_button(int $product_id, string $context = 'loop'): string
{
    if (!$product_id) {
        return '';
    }
    $on = zooboxi_wishlist_has($product_id);

    return sprintf(
        '<button type="button" class="zbx-fav zbx-fav--%1$s%2$s" data-product="%3$d"'
        . ' aria-pressed="%4$s" aria-label="%5$s" title="%5$s">%6$s%7$s</button>',
        esc_attr($context),
        $on ? ' is-on' : '',
        $product_id,
        $on ? 'true' : 'false',
        $on ? esc_attr('إزالة من المفضلة') : esc_attr('أضف للمفضلة'),
        zooboxi_fav_icon(),
        $context === 'single' ? '<span class="zbx-fav__tx">' . ($on ? 'في المفضلة' : 'أضف للمفضلة') . '</span>' : ''
    );
}

/* Classic loop cards: printed BEFORE the product link opens, so the button is
   a sibling of the <a> (a button inside an anchor would navigate on click). */
add_action('woocommerce_before_shop_loop_item', function () {
    global $product;
    if ($product instanceof WC_Product) {
        echo zooboxi_fav_button($product->get_id(), 'loop'); // phpcs:ignore WordPress.Security.EscapeOutput
    }
}, 5);

/* Single product page, right under add-to-cart. */
add_action('woocommerce_single_product_summary', function () {
    global $product;
    if ($product instanceof WC_Product) {
        echo zooboxi_fav_button($product->get_id(), 'single'); // phpcs:ignore WordPress.Security.EscapeOutput
    }
}, 35);

/* ═══════════════════════════════════════════════════════════════════
   3. AJAX
   ═══════════════════════════════════════════════════════════════════ */

add_action('wp_ajax_zbx_fav_toggle', function () {
    check_ajax_referer('zbx-fav', 'nonce');

    $pid = absint($_POST['product_id'] ?? 0);
    if (!$pid || !wc_get_product($pid)) {
        wp_send_json_error(['message' => 'منتج غير معروف'], 404);
    }

    $force  = isset($_POST['force']) ? filter_var(wp_unslash($_POST['force']), FILTER_VALIDATE_BOOLEAN) : null;
    $result = zooboxi_wishlist_toggle($pid, 0, $force);

    wp_send_json_success($result + [
        'message' => $result['state'] === 'added' ? 'أُضيف للمفضلة 💚' : 'أُزيل من المفضلة',
    ]);
});

/* Guests get a clean 401 so the script knows to open the login modal. */
add_action('wp_ajax_nopriv_zbx_fav_toggle', function () {
    wp_send_json_error(['message' => 'سجّل دخولك لحفظ المفضلة', 'login' => true], 401);
});

/* Flush favourites that were hearted before logging in. */
add_action('wp_ajax_zbx_fav_sync', function () {
    check_ajax_referer('zbx-fav', 'nonce');

    $raw = json_decode((string) wp_unslash($_POST['ids'] ?? '[]'), true);
    if (!is_array($raw)) {
        wp_send_json_error(['message' => 'بيانات غير صالحة'], 400);
    }

    foreach (array_slice($raw, 0, 30) as $pid) {
        $pid = absint($pid);
        if ($pid && wc_get_product($pid)) {
            zooboxi_wishlist_toggle($pid, 0, true);
        }
    }

    wp_send_json_success(['count' => zooboxi_wishlist_count(), 'ids' => zooboxi_wishlist()]);
});

/* ═══════════════════════════════════════════════════════════════════
   4. ASSETS
   ═══════════════════════════════════════════════════════════════════ */

add_action('wp_enqueue_scripts', function () {
    $dir = get_stylesheet_directory();
    $uri = get_stylesheet_directory_uri();

    $css = $dir . '/css/zbx-wishlist.css';
    if (file_exists($css)) {
        wp_enqueue_style('zooboxi-wishlist', $uri . '/css/zbx-wishlist.css', ['zooboxi-child'], (string) filemtime($css));
    }

    $js = $dir . '/js/zbx-wishlist.js';
    if (file_exists($js)) {
        wp_enqueue_script('zooboxi-wishlist', $uri . '/js/zbx-wishlist.js', ['jquery'], (string) filemtime($js), true);
        wp_localize_script('zooboxi-wishlist', 'zbxFav', [
            'ajax'     => admin_url('admin-ajax.php'),
            'nonce'    => wp_create_nonce('zbx-fav'),
            'loggedIn' => is_user_logged_in(),
            'ids'      => zooboxi_wishlist(),
            'count'    => zooboxi_wishlist_count(),
            'url'      => function_exists('wc_get_account_endpoint_url') ? wc_get_account_endpoint_url('wishlist') : '',
        ]);
    }
}, 21);

/* ═══════════════════════════════════════════════════════════════════
   5. ACCOUNT SECTION
   ═══════════════════════════════════════════════════════════════════ */

add_filter('woocommerce_get_query_vars', function ($vars) {
    $vars['wishlist'] = 'wishlist';
    return $vars;
});

add_filter('woocommerce_endpoint_wishlist_title', fn() => 'المفضلة');

add_action('woocommerce_account_wishlist_endpoint', function () {
    wc_get_template('myaccount/wishlist.php');
});

/* Slot "المفضلة" into the account nav, right after "مشترياتي". */
add_filter('woocommerce_account_menu_items', function ($items) {
    if (isset($items['wishlist'])) {
        return $items;
    }
    $out = [];
    foreach ($items as $key => $label) {
        $out[$key] = $label;
        if ($key === 'my-products') {
            $out['wishlist'] = 'المفضلة';
        }
    }
    if (!isset($out['wishlist'])) {
        $out['wishlist'] = 'المفضلة';
    }
    return $out;
}, 30);
