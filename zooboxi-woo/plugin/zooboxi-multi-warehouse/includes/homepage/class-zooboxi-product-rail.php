<?php
/**
 * Zooboxi_Product_Rail — a reusable horizontal product carousel.
 *
 * Renders products through WooCommerce's own `content-product` template inside a
 * loop, so ALL loop hooks fire — most importantly the dynamic badges
 * (woocommerce_before_shop_loop_item_title) and the theme's card styling. This is
 * the same proven technique used by Zooboxi_Intelligence::clearance_shortcode()
 * and ::render_fbt_block(), which means homepage rails get HOT/رائج/جديد badges
 * that the native Gutenberg product blocks never showed.
 *
 * Used by both the cacheable homepage shell (global rails) and the per-customer
 * /home-feed endpoint (personalized rails). Pure presentation — no API calls.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_Product_Rail
{
    /** True only while a rail loop is rendering — gates the per-card item marker. */
    private static bool $in_rail = false;

    /**
     * Render a rail.
     *
     * @param array $args {
     *   @type int[]  $ids       Explicit, ordered product IDs (recently-viewed / recs / buy-again).
     *   @type array  $query     WP_Query args (intelligence rails). Ignored if $ids given.
     *   @type string $title     Section title (Arabic).
     *   @type string $subtitle  Optional small subtitle.
     *   @type string $icon      Optional leading emoji/icon.
     *   @type string $zone      Tracking zone, e.g. "home:trending".
     *   @type int    $columns   Card columns hint for WC markup (default 6).
     *   @type string $cta_url   Optional "view all" link.
     *   @type string $cta_label Optional "view all" label.
     *   @type string $class     Extra section class.
     * }
     */
    public static function render(array $args): string
    {
        $args = wp_parse_args($args, [
            'ids'       => null,
            'query'     => null,
            'title'     => '',
            'subtitle'  => '',
            'icon'      => '',
            'zone'      => '',
            'columns'   => 6,
            'cta_url'   => '',
            'cta_label' => '',
            'class'     => '',
        ]);

        if (is_array($args['ids'])) {
            $ids = array_values(array_unique(array_filter(array_map('intval', $args['ids']))));
            if (empty($ids)) {
                return '';
            }
            $q = new WP_Query([
                'post_type'           => 'product',
                'post_status'         => 'publish',
                'post__in'            => $ids,
                'orderby'             => 'post__in',
                'posts_per_page'      => count($ids),
                'ignore_sticky_posts' => true,
                'no_found_rows'       => true,
            ]);
        } elseif (is_array($args['query'])) {
            $q = new WP_Query($args['query']);
        } else {
            return '';
        }

        if (!$q->have_posts()) {
            wp_reset_postdata();
            return '';
        }

        $cols = max(1, (int) $args['columns']);

        // Per-card item-code marker (hidden) so the JS beacon can attribute clicks.
        self::$in_rail = true;
        add_action('woocommerce_after_shop_loop_item', [self::class, 'print_item_marker'], 7);
        // Arabic button text + aria, applied locally so rails are always Arabic even
        // in the REST feed context (where the global frontend filters may not run).
        add_filter('woocommerce_product_add_to_cart_text', [self::class, 'ar_button_text'], 99, 2);
        add_filter('woocommerce_loop_add_to_cart_args', [self::class, 'ar_button_aria'], 99, 2);

        ob_start();
        echo '<section class="zb-rail ' . esc_attr($args['class']) . '" data-zb-zone="' . esc_attr($args['zone']) . '">';

        echo '<div class="zb-rail__head">';
        echo '<div class="zb-rail__heading">';
        if ($args['icon'] !== '') {
            echo '<span class="zb-rail__icon" aria-hidden="true">' . esc_html($args['icon']) . '</span>';
        }
        echo '<h2 class="zb-rail__title">' . esc_html($args['title']) . '</h2>';
        if ($args['subtitle'] !== '') {
            echo '<span class="zb-rail__subtitle">' . esc_html($args['subtitle']) . '</span>';
        }
        echo '</div>';
        echo '<div class="zb-rail__nav">';
        if ($args['cta_url'] !== '' && $args['cta_label'] !== '') {
            echo '<a class="zb-rail__cta" href="' . esc_url($args['cta_url']) . '">' . esc_html($args['cta_label']) . '</a>';
        }
        echo '<button type="button" class="zb-rail__arrow zb-rail__arrow--prev" aria-label="' . esc_attr__('السابق', 'zooboxi') . '">‹</button>';
        echo '<button type="button" class="zb-rail__arrow zb-rail__arrow--next" aria-label="' . esc_attr__('التالي', 'zooboxi') . '">›</button>';
        echo '</div>';
        echo '</div>';

        echo '<div class="zb-rail__scroller woocommerce">';
        echo '<ul class="products columns-' . $cols . ' zb-rail__track">';
        while ($q->have_posts()) {
            $q->the_post();
            wc_get_template_part('content', 'product');
        }
        echo '</ul>';
        echo '</div>';

        echo '</section>';

        remove_action('woocommerce_after_shop_loop_item', [self::class, 'print_item_marker'], 7);
        remove_filter('woocommerce_product_add_to_cart_text', [self::class, 'ar_button_text'], 99);
        remove_filter('woocommerce_loop_add_to_cart_args', [self::class, 'ar_button_aria'], 99);
        self::$in_rail = false;

        wp_reset_postdata();

        // Safety net: the REST feed render path does not run WooCommerce's frontend
        // template-hook stack, so the add_to_cart_text filters above don't catch the
        // loop button there. Force the visible labels + aria to Arabic on our own
        // rail output (no-op on page context where they're already Arabic).
        $html = ob_get_clean();
        $html = strtr($html, [
            '>Add to cart<'    => '>أضف للسلة<',
            '>Select options<' => '>اختر الخيارات<',
            '>Read more<'      => '>عرض المنتج<',
            'aria-label="Add to cart:' => 'aria-label="أضف للسلة:',
            'aria-label="Select options' => 'aria-label="اختر الخيارات',
        ]);
        return $html;
    }

    /** Arabic loop button text (store is Arabic-only; WC ships English defaults). */
    public static function ar_button_text($text, $product)
    {
        if (!($product instanceof WC_Product)) {
            return $text;
        }
        if ($product->is_type('variable') || $product->is_type('grouped')) {
            return __('اختر الخيارات', 'zooboxi');
        }
        if (!$product->is_in_stock()) {
            return __('غير متوفر', 'zooboxi');
        }
        if (!$product->is_purchasable()) {
            return __('عرض المنتج', 'zooboxi');
        }
        return __('أضف للسلة', 'zooboxi');
    }

    /** Arabic accessibility label for the loop add-to-cart link. */
    public static function ar_button_aria($args, $product)
    {
        if (is_array($args) && isset($args['attributes']) && is_array($args['attributes']) && ($product instanceof WC_Product)) {
            $args['attributes']['aria-label'] = sprintf(
                __('أضف %s إلى السلة', 'zooboxi'),
                wp_strip_all_tags($product->get_name())
            );
        }
        return $args;
    }

    /**
     * Try each query in order; render the first one that yields products.
     * Lets the shell degrade gracefully (trending → top-ranked → newest) so a rail
     * is never blank even on a cold intelligence cache.
     */
    public static function render_with_fallback(array $base, array $queries): string
    {
        foreach ($queries as $qa) {
            $html = self::render(array_merge($base, ['query' => $qa, 'ids' => null]));
            if ($html !== '') {
                return $html;
            }
        }
        return '';
    }

    /** Hidden per-card marker carrying the SAP item code (for click attribution). */
    public static function print_item_marker(): void
    {
        if (!self::$in_rail) {
            return;
        }
        global $product;
        if (!$product) {
            return;
        }
        $code = get_post_meta($product->get_id(), '_zooboxi_item_code', true);
        if ($code !== '') {
            echo '<span class="zb-rail-item" data-zb-item="' . esc_attr($code) . '" hidden></span>';
        }
    }

    /* ── Query builders (intelligence rails) ─────────── */

    private static function base(int $limit): array
    {
        return [
            'post_type'           => 'product',
            'post_status'         => 'publish',
            'posts_per_page'      => $limit,
            'ignore_sticky_posts' => true,
            'no_found_rows'       => true,
            'tax_query'           => [[
                'taxonomy' => 'product_visibility',
                'field'    => 'name',
                'terms'    => 'exclude-from-catalog',
                'operator' => 'NOT IN',
            ]],
        ];
    }

    /** Fast movers, ranked. */
    public static function q_trending(int $limit = 12): array
    {
        return array_merge(self::base($limit), [
            'meta_key'   => '_zb_rank_score',
            'orderby'    => 'meta_value_num',
            'order'      => 'DESC',
            'meta_query' => [
                ['key' => '_stock_status', 'value' => 'instock'],
                ['key' => '_zb_demand', 'value' => 'fast'],
            ],
        ]);
    }

    /** Bestsellers: heroes / ABC=A, ranked. */
    public static function q_bestsellers(int $limit = 12): array
    {
        return array_merge(self::base($limit), [
            'meta_key'   => '_zb_rank_score',
            'orderby'    => 'meta_value_num',
            'order'      => 'DESC',
            'meta_query' => [
                'relation' => 'AND',
                ['key' => '_stock_status', 'value' => 'instock'],
                [
                    'relation' => 'OR',
                    ['key' => '_zb_is_hero', 'value' => '1'],
                    ['key' => '_zb_abc', 'value' => 'A'],
                ],
            ],
        ]);
    }

    /** New arrivals (intelligence demand class). */
    public static function q_new(int $limit = 12): array
    {
        return array_merge(self::base($limit), [
            'orderby'    => 'date',
            'order'      => 'DESC',
            'meta_query' => [
                'relation' => 'AND',
                ['key' => '_stock_status', 'value' => 'instock'],
                ['key' => '_zb_demand', 'value' => 'new'],
            ],
        ]);
    }

    /** Clearance collection (channel-safe; floors enforced in backend). */
    public static function q_clearance(int $limit = 12): array
    {
        return array_merge(self::base($limit), [
            'meta_key'   => '_zb_rank_score',
            'orderby'    => 'meta_value_num',
            'order'      => 'DESC',
            'meta_query' => [
                ['key' => '_zb_clearance', 'value' => '1'],
                ['key' => '_stock_status', 'value' => 'instock'],
            ],
        ]);
    }

    /** Fallback: top-ranked in-stock (when a specific demand class is empty). */
    public static function q_top_ranked(int $limit = 12): array
    {
        return array_merge(self::base($limit), [
            'meta_key'   => '_zb_rank_score',
            'orderby'    => 'meta_value_num',
            'order'      => 'DESC',
            'meta_query' => [
                ['key' => '_zb_rank_score', 'compare' => 'EXISTS'],
                ['key' => '_stock_status', 'value' => 'instock'],
            ],
        ]);
    }

    /** Cold-start fallback: newest in-stock (no intelligence meta yet). */
    public static function q_newest(int $limit = 12): array
    {
        return array_merge(self::base($limit), [
            'orderby'    => 'date',
            'order'      => 'DESC',
            'meta_query' => [
                ['key' => '_stock_status', 'value' => 'instock'],
            ],
        ]);
    }
}
