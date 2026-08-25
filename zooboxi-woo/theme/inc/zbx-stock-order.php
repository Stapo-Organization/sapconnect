<?php
/**
 * Zooboxi — availability rules for product listings.
 *
 * Two rules, both about not wasting the shopper's attention:
 *   1. The homepage never shows a product they cannot buy.
 *   2. Everywhere else, unbuyable products sink to the end of the list.
 *
 * Availability here is what the SHOPPER sees, not the global catalogue value:
 * the warehouse plugin filters `woocommerce_product_get_stock_status` by the
 * customer's location, so a product with global stock can still be
 * unavailable from the branch that would serve them. Reading
 * `$product->is_in_stock()` at query time picks that up; the
 * `wc_product_meta_lookup` column does not.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

/** The homepage, where an unbuyable product earns no slot at all. */
function zooboxi_is_home_listing(): bool
{
    return (bool) apply_filters('zooboxi_hide_oos_here', is_front_page() || is_home());
}

/** A customer-facing product list whose ordering we own. */
function zooboxi_is_product_listing($query): bool
{
    if (is_admin() || !$query instanceof WP_Query || !$query->is_main_query()) {
        return false;
    }
    $pt = $query->get('post_type');
    $is_product = ($pt === 'product') || (is_array($pt) && in_array('product', $pt, true));

    return $query->is_post_type_archive('product')
        || $query->is_tax(['product_cat', 'product_tag', 'product_brand'])
        || ($is_product && ($query->is_search() || $query->is_archive()));
}

/* ═══════════════════════════════════════════════════════════════════
   1. HOMEPAGE — out of stock never appears
   ═══════════════════════════════════════════════════════════════════ */

/**
 * Over-fetch so a rail still fills up after the unavailable ones are dropped.
 * post__in rails keep their exact list (their order is meaningful).
 */
add_action('pre_get_posts', function ($query) {
    if (is_admin() || !$query instanceof WP_Query) {
        return;
    }
    if ($query->get('post_type') !== 'product' || $query->get('zbx_instock_only')) {
        return;
    }
    if (!zooboxi_is_home_listing()) {
        return;
    }

    $query->set('zbx_instock_only', 1);

    $want = (int) $query->get('posts_per_page');
    if ($want > 0 && !$query->get('post__in')) {
        $query->set('zbx_want', $want);
        $query->set('posts_per_page', min(72, $want * 4));
    } else {
        $query->set('zbx_want', 0);
    }
}, 20);

add_filter('the_posts', function ($posts, $query) {
    if (!$query instanceof WP_Query || !$query->get('zbx_instock_only') || !$posts) {
        return $posts;
    }
    $want = (int) $query->get('zbx_want');
    $keep = [];

    foreach ($posts as $post) {
        $product = wc_get_product($post->ID);
        if (!$product || !$product->is_in_stock()) {
            continue;
        }
        $keep[] = $post;
        if ($want && count($keep) >= $want) {
            break;
        }
    }

    return $keep;
}, 10, 2);

/* ═══════════════════════════════════════════════════════════════════
   2. CATALOGUE LISTS — out of stock always last
   ═══════════════════════════════════════════════════════════════════ */

/**
 * Across the whole result set (so page 2 never outranks page 1) we sort on the
 * lookup table's global stock_status — the only availability SQL can see.
 */
add_filter('posts_clauses', function ($clauses, $query) {
    if (!zooboxi_is_product_listing($query)) {
        return $clauses;
    }
    global $wpdb;

    if (strpos($clauses['join'], 'zbx_stock') === false) {
        $lookup = $wpdb->prefix . 'wc_product_meta_lookup';
        $clauses['join'] .= " LEFT JOIN {$lookup} AS zbx_stock ON {$wpdb->posts}.ID = zbx_stock.product_id ";
    }

    $sink = "CASE WHEN zbx_stock.stock_status = 'outofstock' THEN 1 ELSE 0 END ASC";
    $clauses['orderby'] = trim((string) $clauses['orderby']) !== ''
        ? $sink . ', ' . $clauses['orderby']
        : $sink;

    return $clauses;
}, 50, 2);

/**
 * Then re-sort the page itself, because location-aware availability can only
 * be evaluated in PHP. Stable: relative order inside each group is untouched.
 */
add_filter('the_posts', function ($posts, $query) {
    if (!zooboxi_is_product_listing($query) || count($posts) < 2) {
        return $posts;
    }
    $available = [];
    $sold_out  = [];

    foreach ($posts as $post) {
        $product = wc_get_product($post->ID);
        if ($product && !$product->is_in_stock()) {
            $sold_out[] = $post;
        } else {
            $available[] = $post;
        }
    }

    return array_merge($available, $sold_out);
}, 20, 2);
