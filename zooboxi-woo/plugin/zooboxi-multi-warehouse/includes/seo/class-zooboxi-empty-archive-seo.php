<?php
/**
 * Keep archives that show nothing out of the index.
 *
 * WooCommerce's own term counts say how many products are *published* in a
 * category, not how many a visitor can actually see. Once sold-out products are
 * hidden the two numbers part company: 460 of the 1,068 categories were already
 * empty, and hiding the sold-out stock emptied 62 more. Yoast keeps every one of
 * them in the sitemap, because their published count is still above zero.
 *
 * So emptiness is decided twice, from the same rule and at the right moment for
 * each: at render time the page itself is asked whether it found anything (the
 * only answer that can't be stale), and for the sitemap the whole tree is
 * counted the way WooCommerce counts it — a parent owns its descendants'
 * products — and cached.
 *
 * Nothing here hides or deletes a term. An empty archive stays reachable and
 * still links onward; it just stops being offered to search engines as a
 * destination.
 */

if (!defined('ABSPATH')) exit;

class Zooboxi_Empty_Archive_SEO
{
    private const CACHE_KEY = 'zooboxi_empty_archive_terms';
    private const CACHE_TTL = 6 * HOUR_IN_SECONDS;

    /** Taxonomies whose archives are product listings. */
    private const TAXONOMIES = ['product_cat', 'product_brand', 'product_tag'];

    public static function hooks(): void
    {
        add_filter('wpseo_robots_array', [self::class, 'noindex_when_empty'], 20);
        add_filter('wpseo_exclude_from_sitemap_by_term_ids', [self::class, 'excluded_term_ids']);

        // The cached tree is only as good as the stock behind it.
        add_action('zooboxi_stock_synced', [self::class, 'flush']);
        add_action('woocommerce_product_set_stock_status', [self::class, 'flush']);
        add_action('update_option_woocommerce_hide_out_of_stock_items', [self::class, 'flush']);
    }

    public static function flush(): void
    {
        delete_transient(self::CACHE_KEY);
    }

    /**
     * A listing that rendered nothing is not a destination.
     *
     * This asks the query that actually ran, so it is right even when a term's
     * stored count disagrees, and right for the shop and search archives too.
     */
    public static function noindex_when_empty(array $robots): array
    {
        if (is_admin() || !self::is_product_listing()) {
            return $robots;
        }

        global $wp_query;
        if ((int) $wp_query->found_posts > 0) {
            return $robots;
        }

        $robots['index'] = 'noindex';

        return $robots;
    }

    /** Term IDs Yoast should leave out of the sitemap. */
    public static function excluded_term_ids($ids)
    {
        $ids = is_array($ids) ? $ids : [];

        return array_values(array_unique(array_merge($ids, self::empty_term_ids())));
    }

    /**
     * Every product term whose archive would render zero products, counting the
     * way WooCommerce does: a parent shows its descendants' products too.
     *
     * @return int[]
     */
    public static function empty_term_ids(): array
    {
        $cached = get_transient(self::CACHE_KEY);
        if (is_array($cached)) {
            return $cached;
        }

        global $wpdb;

        $taxonomies = implode("','", array_map('esc_sql', self::TAXONOMIES));
        $hidingSoldOut = get_option('woocommerce_hide_out_of_stock_items') === 'yes';

        // Count only what a visitor could actually reach: published, in the
        // catalog, and — when the store hides sold-out stock — in stock.
        //
        // This has to ride along on the LEFT JOIN's own condition. As a separate
        // INNER JOIN it would drop every row whose product is NULL, and the terms
        // with no products at all — the ones this whole class exists to find —
        // would vanish from the result instead of counting zero.
        $stockCondition = $hidingSoldOut
            ? "AND EXISTS (
                    SELECT 1 FROM {$wpdb->postmeta} sm
                    WHERE sm.post_id = p.ID
                      AND sm.meta_key = '_stock_status'
                      AND sm.meta_value = 'instock'
               )"
            : '';

        $rows = $wpdb->get_results("
            SELECT tt.term_id, tt.parent, COUNT(DISTINCT p.ID) AS n
            FROM {$wpdb->term_taxonomy} tt
            LEFT JOIN {$wpdb->term_relationships} tr
                   ON tr.term_taxonomy_id = tt.term_taxonomy_id
            LEFT JOIN {$wpdb->posts} p
                   ON p.ID = tr.object_id
                  AND p.post_type = 'product'
                  AND p.post_status = 'publish'
                  AND NOT EXISTS (
                        SELECT 1 FROM {$wpdb->term_relationships} vr
                        JOIN {$wpdb->term_taxonomy} vtt ON vtt.term_taxonomy_id = vr.term_taxonomy_id
                        JOIN {$wpdb->terms} vt ON vt.term_id = vtt.term_id
                        WHERE vr.object_id = p.ID
                          AND vtt.taxonomy = 'product_visibility'
                          AND vt.slug = 'exclude-from-catalog'
                  )
                  {$stockCondition}
            WHERE tt.taxonomy IN ('{$taxonomies}')
            GROUP BY tt.term_id, tt.parent
        ");

        $own = $children = [];
        foreach ($rows as $r) {
            $own[(int) $r->term_id] = (int) $r->n;
            $children[(int) $r->parent][] = (int) $r->term_id;
        }

        $empty = [];
        foreach (array_keys($own) as $termId) {
            if (self::rollup($termId, $own, $children) === 0) {
                $empty[] = $termId;
            }
        }

        set_transient(self::CACHE_KEY, $empty, self::CACHE_TTL);

        return $empty;
    }

    /**
     * Is this request a listing whose emptiness is meaningful?
     *
     * The cart, the account page and any other non-archive answer "no" — only
     * a page that set out to list products can fail to list any.
     */
    private static function is_product_listing(): bool
    {
        if (!function_exists('is_shop')) {
            return false;
        }

        return is_shop() || is_product_taxonomy()
            || (is_search() && get_query_var('post_type') === 'product');
    }

    /** A term's product count plus every descendant's, guarded against cycles. */
    private static function rollup(int $termId, array $own, array $children, array $seen = []): int
    {
        if (isset($seen[$termId])) {
            return 0;
        }
        $seen[$termId] = true;

        $total = $own[$termId] ?? 0;
        foreach ($children[$termId] ?? [] as $childId) {
            $total += self::rollup($childId, $own, $children, $seen);
        }

        return $total;
    }
}
