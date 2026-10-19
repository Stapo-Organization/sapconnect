<?php
/**
 * Catalogue reads for the storefront: listings with facets, home rails, the
 * mega menu, brands, bundles and breadcrumbs.
 *
 * Listings run on the plugin's «فهرس الفلاتر» (Zooboxi_Facet_Index) — the
 * same normalised facets the app filters with — over a base of ids scoped
 * to what reaches this customer (Zv_Scope).
 */

defined('ABSPATH') || exit;

/**
 * Product archives are drawn from Zv_Catalog::listing(); WooCommerce's own main
 * query only has to prove the archive exists (brand pages included — the theme
 * draws the boutique itself).
 */
add_action('pre_get_posts', static function ($q) {
    if (is_admin() || !$q->is_main_query()) {
        return;
    }
    if ($q->is_post_type_archive('product') || $q->is_tax(['product_cat', 'product_tag', 'product_brand']) || ($q->is_search() && $q->get('post_type') === 'product')) {
        $q->set('posts_per_page', 1);
        $q->set('no_found_rows', true);
        // The page lists from Zv_Catalog::listing(), never from this query. Matching nothing keeps
        // the plugin's stock/express ORDER BY (JSON REGEXP over every product in the category,
        // ~1 s on «قطط») from running for a result nobody reads. Term archives and searches
        // still answer 200 (WP::handle_404 spares them when the queried object exists).
        $q->set('post__in', [0]);
    }
}, 50);

final class Zv_Catalog
{
    public const PER_PAGE = 24;

    /** Species roots of the shopping tree (same ids the plugin uses). */
    public const SPECIES = [107 => 'cat', 114 => 'dog', 202 => 'bird', 194 => 'small'];

    public const SORTS = ['recommended', 'popularity', 'price', 'price-desc', 'value', 'date'];

    /** Search relevance for this request: product id → place in the search index's answer. */
    private static array $relevance = [];

    /* ══════════════════════════════════════════════════════════════
       LISTING
       ══════════════════════════════════════════════════════════════ */

    /**
     * @param array{category?:?WP_Term, brand?:string, search?:string, f?:array, min_price?:?float,
     *              max_price?:?float, orderby?:string, page?:int, per_page?:int, rail?:string} $o
     * @return array{ids:int[], total:int, pages:int, page:int, per_page:int, orderby:string,
     *               facets:?array, base_total:int}
     */
    public static function listing(array $o): array
    {
        $per_page = max(1, min(60, (int) ($o['per_page'] ?? self::PER_PAGE)));
        $page     = max(1, (int) ($o['page'] ?? 1));
        $orderby  = in_array($o['orderby'] ?? '', self::SORTS, true) ? $o['orderby'] : 'recommended';
        $category = $o['category'] ?? null;

        $base = self::base_ids($o);

        $facets = null;
        $meta   = [];
        $ids    = $base;
        if (class_exists('Zooboxi_Facet_Index') && !empty($base)) {
            $selected = [];
            foreach ((array) ($o['f'] ?? []) as $facet => $vals) {
                if (in_array($facet, Zooboxi_Facet_Index::FACETS, true) && !empty($vals)) {
                    $selected[$facet] = array_slice(array_values((array) $vals), 0, 20);
                }
            }
            $price = ['min' => $o['min_price'] ?? null, 'max' => $o['max_price'] ?? null];
            $species = $category instanceof WP_Term ? self::species_of($category) : '';
            $whole = !$category && empty($o['brand']) && empty($o['search']);
            try {
                $res = Zooboxi_Facet_Index::search($base, $selected, $price, $species, false, zv_lang(), $whole);
                $ids    = $res['ids'];
                $meta   = $res['meta'];
                $facets = $res['facets'];
            } catch (Throwable $e) {
                $ids = $base;
            }
        }

        $ids = self::order($ids, $meta, $orderby);

        $total = count($ids);
        return [
            'ids'        => array_slice($ids, ($page - 1) * $per_page, $per_page),
            'total'      => $total,
            'pages'      => $total ? (int) ceil($total / $per_page) : 0,
            'page'       => $page,
            'per_page'   => $per_page,
            'orderby'    => $orderby,
            'facets'     => $facets,
            'base_total' => count($base),
        ];
    }

    /**
     * Product ids in scope (category / brand / search) that reach this customer.
     * Cached per scope for ten minutes; searches are never cached.
     */
    public static function base_ids(array $o): array
    {
        $category = $o['category'] ?? null;
        $brand    = sanitize_title((string) ($o['brand'] ?? ''));
        $search   = trim((string) ($o['search'] ?? ''));

        $tax = ['relation' => 'AND', [
            'taxonomy' => 'product_visibility',
            'field'    => 'name',
            'terms'    => ['exclude-from-catalog', 'outofstock'],
            'operator' => 'NOT IN',
        ]];
        if ($category instanceof WP_Term) {
            $tax[] = ['taxonomy' => $category->taxonomy, 'field' => 'term_id', 'terms' => (int) $category->term_id, 'include_children' => true];
        }
        if ($brand !== '' && taxonomy_exists('product_brand')) {
            $tax[] = ['taxonomy' => 'product_brand', 'field' => 'slug', 'terms' => [$brand]];
        }

        $meta = [];
        $re = Zv_Scope::regexp();
        $xc = Zv_Scope::get()['express_code'];
        if (!empty($o['express']) && $xc !== '') {
            $re = '(^|,)' . preg_quote($xc, '/') . '(,|$)';
        }
        $meta[] = $re !== ''
            ? ['key' => '_zb_avail_branches', 'value' => $re, 'compare' => 'REGEXP']
            : ['key' => '_zb_avail_branches', 'value' => '', 'compare' => '!='];

        $args = [
            'post_type'           => 'product',
            'post_status'         => 'publish',
            'fields'              => 'ids',
            'posts_per_page'      => -1,
            'no_found_rows'       => true,
            'ignore_sticky_posts' => true,
            'orderby'             => 'ID',
            'order'               => 'DESC',
            'tax_query'           => $tax,
            'meta_query'          => $meta,
            'suppress_filters'    => true,
        ];

        if ($search !== '') {
            $args['s'] = $search;
            $args['suppress_filters'] = false;
            $ids = array_map('intval', (new WP_Query($args))->posts);
            // A barcode or SAP item code typed into search finds its product.
            $exact = self::identifier_ids($search);
            $ids = array_values(array_unique(array_merge($exact, $ids)));
            // Best match first (the plugin's search index), then the rest as found.
            self::$relevance = [];
            if (class_exists('Zooboxi_Search_Index')) {
                $rank = array_flip(Zooboxi_Search_Index::search($search, 600));
                foreach ($exact as $id) {
                    $rank[$id] = -1;
                }
                self::$relevance = $rank;
            }
            return $ids;
        }

        $built = class_exists('Zooboxi_Facet_Index') ? (string) get_option(Zooboxi_Facet_Index::OPTION_BUILT, '0') : '0';
        $key = 'zv_base_' . md5(wp_json_encode($args) . '|' . Zv_Scope::key() . '|' . $built);
        $cached = get_transient($key);
        if (is_array($cached)) {
            return array_map('intval', $cached);
        }
        $ids = array_map('intval', (new WP_Query($args))->posts);
        set_transient($key, $ids, 10 * MINUTE_IN_SECONDS);
        return $ids;
    }

    /** Products whose barcode (SKU) or SAP item code equals the query. */
    private static function identifier_ids(string $q): array
    {
        $q = trim($q);
        if (!preg_match('/^[A-Za-z0-9\-]{5,20}$/', $q)) {
            return [];
        }
        global $wpdb;
        $rows = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT IF(p.post_type = 'product_variation', p.post_parent, p.ID)
               FROM {$wpdb->postmeta} m JOIN {$wpdb->posts} p ON p.ID = m.post_id
              WHERE m.meta_key IN ('_sku', '_zooboxi_item_code') AND m.meta_value = %s
                AND p.post_status = 'publish'",
            $q
        ));
        return array_map('intval', (array) $rows);
    }

    /**
     * In stock first; with express open, what arrives in two hours next; then the sort.
     */
    private static function order(array $ids, array $meta, string $orderby): array
    {
        if (count($ids) < 2) {
            return $ids;
        }
        global $wpdb;
        $list = implode(',', array_map('intval', $ids));

        $key = [];
        switch ($orderby) {
            case 'price':
            case 'price-desc':
                foreach ($ids as $id) {
                    $key[$id] = isset($meta[$id]) ? (float) $meta[$id]['price'] : (float) get_post_meta($id, '_price', true);
                }
                break;
            case 'value':
                foreach ($ids as $id) {
                    $v = isset($meta[$id]['per_kg']) ? (float) $meta[$id]['per_kg'] : 0.0;
                    $key[$id] = $v > 0 ? $v : PHP_FLOAT_MAX;
                }
                break;
            case 'date':
                foreach ($wpdb->get_results("SELECT ID, UNIX_TIMESTAMP(post_date) t FROM {$wpdb->posts} WHERE ID IN ($list)") as $r) {
                    $key[(int) $r->ID] = -(int) $r->t;
                }
                break;
            case 'popularity':
                foreach ($wpdb->get_results("SELECT product_id, total_sales FROM {$wpdb->prefix}wc_product_meta_lookup WHERE product_id IN ($list)") as $r) {
                    $key[(int) $r->product_id] = -(float) $r->total_sales;
                }
                break;
            default:
                if (self::$relevance) {
                    // A search: how well it matches, not how well it sells.
                    foreach ($ids as $id) {
                        $key[$id] = self::$relevance[$id] ?? 100000;
                    }
                    break;
                }
                foreach ($wpdb->get_results("SELECT post_id, meta_value FROM {$wpdb->postmeta} WHERE meta_key = '_zb_rank_score' AND post_id IN ($list)") as $r) {
                    $key[(int) $r->post_id] = -(float) $r->meta_value;
                }
        }

        // Express first only while the branch is open and the sort is ours (a search keeps match order).
        $express = [];
        $code = Zv_Scope::get()['express_code'];
        if ($code !== '' && $orderby === 'recommended' && !self::$relevance) {
            $re = '(^|,)' . preg_quote($code, '/') . '(,|$)';
            foreach ($wpdb->get_col($wpdb->prepare("SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key = '_zb_avail_branches' AND post_id IN ($list) AND meta_value REGEXP %s", $re)) as $pid) {
                $express[(int) $pid] = 1;
            }
        }

        // A card without a picture sells nothing: those go after the pictured ones.
        $pictured = [];
        foreach ($wpdb->get_col("SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key = '_thumbnail_id' AND meta_value > 0 AND post_id IN ($list)") as $pid) {
            $pictured[(int) $pid] = 1;
        }

        $desc = $orderby === 'price-desc';
        usort($ids, static function ($a, $b) use ($meta, $key, $express, $pictured, $desc) {
            $sa = (int) ($meta[$a]['instock'] ?? 1);
            $sb = (int) ($meta[$b]['instock'] ?? 1);
            if ($sa !== $sb) {
                return $sb <=> $sa;
            }
            $ea = $express[$a] ?? 0;
            $eb = $express[$b] ?? 0;
            if ($ea !== $eb) {
                return $eb <=> $ea;
            }
            $pa = $pictured[$a] ?? 0;
            $pb = $pictured[$b] ?? 0;
            if ($pa !== $pb) {
                return $pb <=> $pa;
            }
            $ka = $key[$a] ?? 0;
            $kb = $key[$b] ?? 0;
            if ($ka == $kb) {
                return $b <=> $a;
            }
            return $desc ? ($kb <=> $ka) : ($ka <=> $kb);
        });
        return $ids;
    }

    public static function sort_labels(): array
    {
        return [
            'recommended' => zv_t('الأنسب لك', 'Recommended'),
            'popularity'  => zv_t('الأكثر مبيعاً', 'Best selling'),
            'price'       => zv_t('السعر: من الأقل', 'Price: low to high'),
            'price-desc'  => zv_t('السعر: من الأعلى', 'Price: high to low'),
            'value'       => zv_t('الأوفر للكيلو', 'Best value per kg'),
            'date'        => zv_t('الأحدث', 'Newest'),
        ];
    }

    /** Request → listing options. */
    public static function request_options(?WP_Term $term = null): array
    {
        $f = [];
        if (class_exists('Zooboxi_Facet_Index')) {
            foreach (Zooboxi_Facet_Index::FACETS as $facet) {
                $raw = $_GET['f_' . $facet] ?? '';
                $raw = is_array($raw) ? implode(',', array_map('strval', wp_unslash($raw))) : (string) wp_unslash($raw);
                if ($raw === '') {
                    continue;
                }
                $vals = array_values(array_filter(array_map(
                    static fn($v) => $facet === 'brand' ? rawurldecode(sanitize_title(rawurldecode(trim($v)))) : sanitize_key($v),
                    explode(',', $raw)
                )));
                if ($vals) {
                    $f[$facet] = $vals;
                }
            }
        }
        $num = static fn($k) => (isset($_GET[$k]) && $_GET[$k] !== '' && is_numeric($_GET[$k])) ? (float) $_GET[$k] : null;
        $category = $term && $term->taxonomy === 'product_cat' ? $term : null;
        $zb_cat = '';
        if ($term && $term->taxonomy === 'product_brand' && !empty($_GET['zb_cat'])) {
            $shelf = get_term_by('slug', sanitize_title(wp_unslash($_GET['zb_cat'])), 'product_cat');
            if ($shelf instanceof WP_Term) {
                $category = $shelf;
                $zb_cat = $shelf->slug;
            }
        }
        return [
            'category'  => $category,
            'zb_cat'    => $zb_cat,
            'brand'     => $term && $term->taxonomy === 'product_brand' ? $term->slug : '',
            'search'    => is_search() ? get_search_query(false) : '',
            'f'         => $f,
            'min_price' => $num('min_price'),
            'max_price' => $num('max_price'),
            'orderby'   => isset($_GET['orderby']) ? sanitize_key(wp_unslash($_GET['orderby'])) : 'recommended',
            'express'   => !empty($_GET['express']) && Zv_Scope::get()['express_open'],
            'page'      => max(1, (int) get_query_var('paged'), isset($_GET['pg']) ? (int) $_GET['pg'] : 1),
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       CARDS
       ══════════════════════════════════════════════════════════════ */

    /** The card data the theme draws (the app's card shape plus a few web extras). */
    public static function card(int $id): ?array
    {
        $product = wc_get_product($id);
        if (!$product || $product->get_status() !== 'publish') {
            return null;
        }
        if (class_exists('Zooboxi_Product_DTO')) {
            $c = Zooboxi_Product_DTO::card($product);
            if (!$c) {
                return null;
            }
        } else {
            $c = [
                'id' => $id, 'name' => $product->get_name(), 'brand' => null,
                'image' => wp_get_attachment_image_url($product->get_image_id(), 'woocommerce_single') ?: wc_placeholder_img_src(),
                'gallery_thumb' => wp_get_attachment_image_url($product->get_image_id(), 'woocommerce_thumbnail') ?: wc_placeholder_img_src(),
                'price' => (float) wc_get_price_to_display($product), 'regular_price' => (float) wc_get_price_to_display($product, ['price' => $product->get_regular_price()]),
                'on_sale' => $product->is_on_sale(), 'price_from' => $product->is_type('variable'), 'discount_pct' => 0,
                'stock_status' => $product->is_in_stock() ? 'instock' : 'outofstock', 'is_variable' => $product->is_type('variable'),
                'badge' => null, 'delivery_chip' => null, 'wishlisted' => false,
            ];
        }
        $c['url']   = get_permalink($id);
        $c['sizes'] = [];
        if ($product->is_type('variable')) {
            // «يبدأ من» quotes the cheapest size THIS customer can actually buy.
            $min = null;
            $reg = 0.0;
            $live = [];
            foreach ($product->get_children() as $vid) {
                $v = wc_get_product($vid);
                if (!$v || $v->get_status() !== 'publish' || !$v->is_purchasable() || !$v->is_in_stock()) {
                    continue;
                }
                $live[] = $v;
                $p = (float) wc_get_price_to_display($v);
                if ($p > 0 && ($min === null || $p < $min)) {
                    $min = $p;
                    $reg = (float) wc_get_price_to_display($v, ['price' => $v->get_regular_price()]);
                }
            }
            if ($min === null) {
                $c['stock_status'] = 'outofstock';
            } else {
                $c['price']         = $min;
                $c['regular_price'] = max($reg, $min);
                $c['on_sale']       = $reg > $min;
                $c['discount_pct']  = $reg > $min ? (int) round((1 - $min / $reg) * 100) : 0;
                $c['price_from']    = count($live) > 1;
            }
            $c['sizes'] = self::size_labels($product, $live);
        }
        $c['bundle'] = (bool) get_post_meta($id, '_zb_bundle_id', true);
        if ($c['bundle'] && class_exists('Zooboxi_V2_Bundles_Controller')) {
            try {
                $ext = Zooboxi_V2_Bundles_Controller::extend($c);
                if (!empty($ext['image'])) {
                    $c['image'] = $ext['image'];
                    $c['gallery_thumb'] = $ext['image'];
                }
            } catch (Throwable $e) {
                // the plain product image stays
            }
        }
        return $c;
    }

    /** @return array<int,array> cards in the given order */
    public static function cards(array $ids): array
    {
        $out = [];
        if (!empty($ids)) {
            _prime_post_caches(array_map('intval', $ids), true, true);
        }
        foreach ($ids as $id) {
            $c = self::card((int) $id);
            // A product without a price index shows «0.00» — never on a shelf.
            if ($c && (float) ($c['price'] ?? 0) > 0) {
                $out[] = $c;
            }
        }
        return $out;
    }

    /** «650 غ · 18 كغ» — the sizes a variable product comes in. */
    public static function size_labels(WC_Product $product, array $variations = []): array
    {
        if (!$product->is_type('variable')) {
            return [];
        }
        $attrs = array_keys($product->get_variation_attributes());
        $attr  = $attrs[0] ?? ''; // the first attribute is the size; packs (حبة/كرتون) speak for themselves
        if ($attr === '') {
            return [];
        }
        $labels = [];
        foreach ($variations as $v) {
            $slug = (string) $v->get_attribute($attr) ?: (string) ($v->get_variation_attributes()['attribute_' . sanitize_title($attr)] ?? '');
            if ($slug === '') {
                continue;
            }
            $t = taxonomy_exists($attr) ? get_term_by('slug', $slug, $attr) : null;
            $labels[] = $t ? $t->name : rawurldecode($slug);
        }
        usort($labels, static fn($a, $b) => self::grams($a) <=> self::grams($b));
        return array_slice(array_values(array_unique($labels)), 0, 4);
    }

    /** Weight in grams parsed from a label («1.8 كغ», «650 غ», «2 لتر») — 0 when unknown. */
    public static function grams(string $label): float
    {
        $l = str_replace(['٫', ','], '.', strtr($label, ['٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9']));
        if (preg_match('/(\d+(?:\.\d+)?)\s*(كغ|كجم|كيلو|kg)/iu', $l, $m)) {
            return (float) $m[1] * 1000;
        }
        if (preg_match('/(\d+(?:\.\d+)?)\s*(غ|جم|جرام|g\b|gm)/iu', $l, $m)) {
            return (float) $m[1];
        }
        if (preg_match('/(\d+(?:\.\d+)?)\s*(لتر|l\b)/iu', $l, $m)) {
            return (float) $m[1] * 1000;
        }
        if (preg_match('/(\d+(?:\.\d+)?)\s*(مل|ml)/iu', $l, $m)) {
            return (float) $m[1];
        }
        return 0.0;
    }

    /* ══════════════════════════════════════════════════════════════
       TREE, BREADCRUMBS, SPECIES
       ══════════════════════════════════════════════════════════════ */

    public static function species_of(WP_Term $term): string
    {
        if (isset(self::SPECIES[$term->term_id])) {
            return self::SPECIES[$term->term_id];
        }
        foreach (get_ancestors($term->term_id, 'product_cat', 'taxonomy') as $a) {
            if (isset(self::SPECIES[$a])) {
                return self::SPECIES[$a];
            }
        }
        return '';
    }

    /** @return WP_Term[] root → term, inside the species tree only */
    public static function trail(WP_Term $term): array
    {
        $chain = [];
        foreach (array_reverse(get_ancestors($term->term_id, $term->taxonomy, 'taxonomy')) as $a) {
            $t = get_term($a, $term->taxonomy);
            if ($t instanceof WP_Term) {
                $chain[] = $t;
            }
        }
        $chain[] = $term;
        return $chain;
    }

    /** The product's deepest category inside the species tree (its "home" shelf). */
    public static function primary_category(int $product_id): ?WP_Term
    {
        $best = null;
        $depth = -1;
        foreach (wp_get_post_terms($product_id, 'product_cat') as $t) {
            if (self::species_of($t) === '') {
                continue;
            }
            $d = count(get_ancestors($t->term_id, 'product_cat', 'taxonomy'));
            if ($d > $depth) {
                $depth = $d;
                $best = $t;
            }
        }
        return $best;
    }

    /**
     * The mega menu, shaped by what each pet's shelves actually hold:
     * departments in shopping order (food first), each with its shelves
     * pictured by their best seller; food grouped by type / age / need;
     * thin departments filled with their best sellers; the pet's own
     * brands on the side. Built from the live tree, cached six hours.
     */
    public static function menu(): array
    {
        $key = 'zv_menu_' . zv_lang() . '_v4';
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }
        $out = [];
        foreach (self::SPECIES as $root_id => $species) {
            $root = get_term($root_id, 'product_cat');
            if (!$root instanceof WP_Term) {
                continue;
            }
            $depts = [];
            $children = get_terms(['taxonomy' => 'product_cat', 'parent' => $root_id, 'hide_empty' => true, 'orderby' => 'count', 'order' => 'DESC', 'number' => 10]);
            foreach (is_array($children) ? $children : [] as $child) {
                [$rank, $icon] = self::dept_kind(html_entity_decode($child->name), $species);
                $used = [];
                $leaves = get_terms(['taxonomy' => 'product_cat', 'parent' => $child->term_id, 'hide_empty' => true, 'orderby' => 'count', 'order' => 'DESC', 'number' => 9]);
                $tiles = [];
                foreach (is_array($leaves) ? $leaves : [] as $leaf) {
                    $pid = self::menu_pick($leaf->term_id, $used);
                    $tiles[] = [
                        'name'  => html_entity_decode($leaf->name),
                        'url'   => get_term_link($leaf),
                        'count' => (int) $leaf->count,
                        'img'   => $pid ? (string) wp_get_attachment_image_url((int) get_post_thumbnail_id($pid), 'woocommerce_thumbnail') : '',
                    ];
                }
                $groups = $icon === 'bowl' && count($tiles) > 4 ? self::food_groups($tiles) : [['label' => '', 'tiles' => $tiles]];
                // Thin departments are filled with what sells in them.
                $top = [];
                $room = count($tiles) <= 3 ? 6 : (count($tiles) <= 6 ? 3 : 0);
                if ($room) {
                    foreach (self::menu_top($child->term_id, $room, $used) as $pid) {
                        $top[] = [
                            'name' => get_the_title($pid),
                            'url'  => get_permalink($pid),
                            'img'  => (string) wp_get_attachment_image_url((int) get_post_thumbnail_id($pid), 'woocommerce_thumbnail'),
                        ];
                    }
                }
                $dcount = (new WP_Query([
                    'post_type' => 'product', 'post_status' => 'publish', 'fields' => 'ids', 'posts_per_page' => 1,
                    'suppress_filters' => true,
                    'tax_query' => [['taxonomy' => 'product_cat', 'field' => 'term_id', 'terms' => $child->term_id, 'include_children' => true]],
                ]))->found_posts;
                $dname = self::dept_label(html_entity_decode($child->name));
                $depts[] = [
                    'name'   => $dname,
                    'for'    => preg_match('/القطط|الكلاب|الطيور|القوارض|الارانب|الأرانب|الهامستر|الهماستر/u', $dname) ? '' : zv_for_pet($species, html_entity_decode($root->name)),
                    'url'    => get_term_link($child),
                    'count'  => max((int) $child->count, (int) $dcount),
                    'icon'   => $icon,
                    'rank'   => $rank,
                    'groups' => $groups,
                    'top'    => $top,
                ];
            }
            usort($depts, static fn($a, $b) => [$a['rank'], -$a['count']] <=> [$b['rank'], -$b['count']]);
            $out[] = [
                'id'      => $root_id,
                'species' => $species,
                'name'    => html_entity_decode($root->name),
                'title'   => self::species_title($species, html_entity_decode($root->name)),
                'url'     => get_term_link($root),
                'count'   => (int) $root->count,
                'depts'   => $depts,
                'cols'    => array_map(static fn($d) => ['name' => $d['name'], 'url' => $d['url']], $depts),
                'brands'  => self::species_brands($root_id, 6),
            ];
        }
        set_transient($key, $out, 6 * HOUR_IN_SECONDS);
        return $out;
    }

    /** «القطط» — the pet with its article, for headings. */
    public static function species_title(string $species, string $name): string
    {
        $ar = ['cat' => 'القطط', 'dog' => 'الكلاب', 'bird' => 'الطيور', 'small' => 'الحيوانات الصغيرة'];
        return zv_lang() === 'en' ? $name : ($ar[$species] ?? $name);
    }

    /** Shopping order and pictogram for a department, read from its name. */
    private static function dept_kind(string $name, string $species): array
    {
        if (preg_match('/بكج/u', $name)) {
            return [9, 'gift'];
        }
        if (preg_match('/مستلزمات الرمل/u', $name)) {
            return [5, 'litterbox'];
        }
        if (preg_match('/رمل/u', $name)) {
            return [2, 'litter'];
        }
        if (preg_match('/طعام|الطعام|food/iu', $name)) {
            return [1, 'bowl'];
        }
        if (preg_match('/مكاف|فيتامين|treat/iu', $name)) {
            return [3, 'bone'];
        }
        if (preg_match('/صحة|health/iu', $name)) {
            return [4, 'health'];
        }
        if (preg_match('/تنظيف|العناية|groom/iu', $name)) {
            return [6, 'brush'];
        }
        if (preg_match('/مستلزمات|supplies/iu', $name)) {
            return [7, in_array($species, ['bird', 'small'], true) ? 'cage' : 'toy'];
        }
        return [8, 'tag'];
    }

    /** «طعام» and «الطعام» read the same in a pet's menu. */
    private static function dept_label(string $name): string
    {
        return $name === 'طعام' ? 'الطعام' : $name;
    }

    /** Food shelves sorted into what owners actually choose by. */
    private static function food_groups(array $tiles): array
    {
        $g = ['type' => [], 'age' => [], 'need' => []];
        foreach ($tiles as $t) {
            if (preg_match('/رطب|جاف|حليب|سوائل/u', $t['name'])) {
                $g['type'][] = $t;
            } elseif (preg_match('/صغيرة|بوبي|البوبي|البالغة|المسنة|بالغ|مسن/u', $t['name'])) {
                $g['age'][] = $t;
            } else {
                $g['need'][] = $t;
            }
        }
        $labels = ['type' => zv_t('حسب النوع', 'By type'), 'age' => zv_t('حسب العمر', 'By age'), 'need' => zv_t('احتياجات خاصة', 'Special needs')];
        $out = [];
        foreach ($g as $k => $list) {
            if ($list) {
                $out[] = ['label' => $labels[$k], 'tiles' => $list];
            }
        }
        return $out;
    }

    /** The best-selling visible product of a shelf that has a photo, not already shown. */
    private static function menu_pick(int $term_id, array &$used): int
    {
        foreach (self::menu_top($term_id, 4, $used) as $pid) {
            return $pid;
        }
        return 0;
    }

    /** Best sellers of a department (ids), skipping ones already shown; records what it returns. */
    private static function menu_top(int $term_id, int $n, array &$used): array
    {
        if ($n < 1) {
            return [];
        }
        $ids = get_posts([
            'post_type'        => 'product',
            'post_status'      => 'publish',
            'fields'           => 'ids',
            'posts_per_page'   => $n + count($used) + 2,
            'no_found_rows'    => true,
            'suppress_filters' => true,
            'tax_query'        => [
                ['taxonomy' => 'product_cat', 'field' => 'term_id', 'terms' => $term_id, 'include_children' => true],
                ['taxonomy' => 'product_visibility', 'field' => 'name', 'terms' => ['exclude-from-catalog'], 'operator' => 'NOT IN'],
            ],
            'meta_query'       => [
                ['key' => '_thumbnail_id', 'compare' => 'EXISTS'],
                ['key' => '_zb_avail_branches', 'value' => '', 'compare' => '!='],
                ['key' => '_zb_bundle_id', 'compare' => 'NOT EXISTS'],
            ],
            'meta_key'         => 'total_sales',
            'orderby'          => 'meta_value_num',
            'order'            => 'DESC',
        ]);
        $out = [];
        foreach ($ids as $pid) {
            $pid = (int) $pid;
            if (isset($used[$pid])) {
                continue;
            }
            $used[$pid] = true;
            $out[] = $pid;
            if (count($out) >= $n) {
                break;
            }
        }
        return $out;
    }

    /** The brands a pet's shelves carry most, with logos. */
    public static function species_brands(int $root_id, int $n = 6): array
    {
        global $wpdb;
        if (!taxonomy_exists('product_brand')) {
            return [];
        }
        $cats = array_map('intval', array_merge([$root_id], (array) get_term_children($root_id, 'product_cat')));
        $in = implode(',', $cats);
        $rows = $wpdb->get_results(
            "SELECT bt.term_id, COUNT(DISTINCT tr.object_id) AS n
               FROM {$wpdb->term_relationships} tr
               JOIN {$wpdb->term_taxonomy} bt ON bt.term_taxonomy_id = tr.term_taxonomy_id AND bt.taxonomy = 'product_brand'
               JOIN {$wpdb->term_relationships} tc ON tc.object_id = tr.object_id
               JOIN {$wpdb->term_taxonomy} ct ON ct.term_taxonomy_id = tc.term_taxonomy_id AND ct.taxonomy = 'product_cat' AND ct.term_id IN ($in)
               JOIN {$wpdb->posts} p ON p.ID = tr.object_id AND p.post_status = 'publish' AND p.post_type = 'product'
              GROUP BY bt.term_id ORDER BY n DESC LIMIT 40"
        ); // phpcs:ignore
        $skip = ['feline-go', 'felyn-go-en', 'whimzees-en'];
        $seen = [];
        $out = [];
        foreach ((array) $rows as $r) {
            $t = get_term((int) $r->term_id, 'product_brand');
            if (!$t instanceof WP_Term || in_array($t->slug, $skip, true)) {
                continue;
            }
            $norm = preg_replace('/[^a-z]/', '', strtolower(remove_accents(html_entity_decode($t->name))));
            $logo_id = (int) get_term_meta($t->term_id, 'thumbnail_id', true);
            $logo = $logo_id ? wp_get_attachment_image_url($logo_id, 'medium') : '';
            if (!$logo || isset($seen[$norm])) {
                continue;
            }
            $seen[$norm] = true;
            $out[] = ['name' => html_entity_decode($t->name), 'url' => get_term_link($t), 'logo' => $logo];
            if (count($out) >= $n) {
                break;
            }
        }
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       HOME
       ══════════════════════════════════════════════════════════════ */

    /** Top products for one pet, ranked — what this customer can actually get. */
    public static function rail_species(int $root_id, int $n = 10): array
    {
        $term = get_term($root_id, 'product_cat');
        if (!$term instanceof WP_Term) {
            return [];
        }
        return self::listing(['category' => $term, 'orderby' => 'recommended', 'per_page' => $n])['ids'];
    }

    /** Newest arrivals — single products; bundles have their own band. */
    public static function rail_new(int $n = 10): array
    {
        $ids = self::listing(['orderby' => 'date', 'per_page' => $n + 16])['ids'];
        $ids = array_values(array_filter($ids, static fn($id) => !get_post_meta($id, '_zb_bundle_id', true)));
        return array_slice($ids, 0, $n);
    }

    /** The bundles that reach this customer, best rank first. */
    public static function bundle_ids(int $n = 8): array
    {
        $term = get_term_by('slug', 'zb-bundles', 'product_cat');
        if (!$term instanceof WP_Term) {
            return [];
        }
        return self::listing(['category' => $term, 'orderby' => 'recommended', 'per_page' => $n])['ids'];
    }

    /** Brands with a logo, most products first; known duplicate spellings skipped. */
    public static function brands(int $n = 12): array
    {
        $key = 'zv_brands_' . $n . '_v1';
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }
        $out = [];
        if (!taxonomy_exists('product_brand')) {
            return $out;
        }
        $skip = ['feline-go', 'felyn-go-en', 'whimzees-en'];
        $seen = [];
        $terms = get_terms(['taxonomy' => 'product_brand', 'hide_empty' => true, 'orderby' => 'count', 'order' => 'DESC', 'number' => $n * 2]);
        foreach (is_array($terms) ? $terms : [] as $t) {
            if (in_array($t->slug, $skip, true)) {
                continue;
            }
            $norm = preg_replace('/[^a-z]/', '', strtolower(remove_accents(html_entity_decode($t->name))));
            if (isset($seen[$norm])) {
                continue;
            }
            $logo_id = (int) get_term_meta($t->term_id, 'thumbnail_id', true);
            $logo = $logo_id ? wp_get_attachment_image_url($logo_id, 'medium') : '';
            if (!$logo) {
                continue;
            }
            $seen[$norm] = true;
            $out[] = ['name' => html_entity_decode($t->name), 'url' => get_term_link($t), 'logo' => $logo, 'count' => (int) $t->count];
            if (count($out) >= $n) {
                break;
            }
        }
        set_transient($key, $out, 6 * HOUR_IN_SECONDS);
        return $out;
    }

    /* ══════════════════════════════════════════════════════════════
       BRAND PAGES
       ══════════════════════════════════════════════════════════════ */

    /**
     * What a brand page shows about the brand: the owner-published boutique
     * kit (hero, tiles, story — from /admin/brand-pages) when there is one,
     * else just the logo and name.
     */
    public static function brand_profile(WP_Term $term): array
    {
        $logo_id = (int) get_term_meta($term->term_id, 'thumbnail_id', true);
        $p = [
            'name'    => html_entity_decode($term->name),
            'logo'    => $logo_id ? (string) wp_get_attachment_image_url($logo_id, 'medium') : '',
            'hero'    => '',
            'tiles'   => [],
            'tagline' => '',
            'lead'    => '',
            'country' => '',
            'since'   => '',
            'accent'  => '',
            'dark'    => '',
            'slug'    => $term->slug,
        ];
        $r = class_exists('Zooboxi_Brand_Page') ? Zooboxi_Brand_Page::resolve() : null;
        if (!$r || empty($r['payload']) || (int) $r['term']->term_id !== (int) $term->term_id) {
            return $p;
        }
        $pl  = $r['payload'];
        $kit = (array) ($pl['kit'] ?? []);
        $p['name']    = (string) ($pl['name'] ?? $p['name']);
        $p['logo']    = $p['logo'] ?: (string) ($pl['logo_url'] ?? '');
        $p['hero']    = (string) ($pl['hero_url'] ?? '');
        $p['tagline'] = trim((string) ($kit['tagline_ar'] ?? ''));
        $p['lead']    = trim((string) ($kit['audience_ar'] ?? ''));
        $p['country'] = self::country_ar(trim((string) ($kit['country'] ?? '')));
        $p['since']   = preg_match('/(1[89]\d\d|20\d\d)/', (string) ($kit['founded'] ?? ''), $m) ? $m[1] : '';
        foreach (['accent' => 'accent', 'dark' => 'accent_dark'] as $k => $src) {
            $c = trim((string) ($kit[$src] ?? ''));
            $p[$k] = preg_match('/^#[0-9a-fA-F]{6}$/', $c) ? $c : '';
        }
        foreach ((array) ($pl['tiles'] ?? []) as $t) {
            if (!empty($t['url'])) {
                $p['tiles'][] = ['img' => (string) $t['url'], 'label' => trim((string) ($t['headline_ar'] ?? ''))];
            }
        }
        $p['tiles'] = array_slice($p['tiles'], 0, 2);
        return $p;
    }

    private static function country_ar(string $c): string
    {
        if ($c === '' || zv_lang() === 'en') {
            return $c;
        }
        $map = [
            'united kingdom' => 'المملكة المتحدة', 'uk' => 'المملكة المتحدة', 'england' => 'المملكة المتحدة',
            'united states' => 'الولايات المتحدة', 'usa' => 'الولايات المتحدة', 'us' => 'الولايات المتحدة',
            'germany' => 'ألمانيا', 'france' => 'فرنسا', 'italy' => 'إيطاليا', 'spain' => 'إسبانيا',
            'netherlands' => 'هولندا', 'belgium' => 'بلجيكا', 'denmark' => 'الدنمارك', 'poland' => 'بولندا',
            'czech republic' => 'التشيك', 'czechia' => 'التشيك', 'austria' => 'النمسا', 'switzerland' => 'سويسرا',
            'canada' => 'كندا', 'thailand' => 'تايلاند', 'china' => 'الصين', 'japan' => 'اليابان',
            'south korea' => 'كوريا الجنوبية', 'korea' => 'كوريا الجنوبية', 'turkey' => 'تركيا', 'türkiye' => 'تركيا',
            'australia' => 'أستراليا', 'new zealand' => 'نيوزيلندا', 'brazil' => 'البرازيل',
            'saudi arabia' => 'السعودية', 'united arab emirates' => 'الإمارات', 'uae' => 'الإمارات',
        ];
        return $map[strtolower($c)] ?? $c;
    }

    /**
     * The shelves a brand fills (leaf categories under a pet), most stocked
     * first — «الطعام الرطب للقطط». Cached six hours.
     */
    public static function brand_depts(WP_Term $brand, int $n = 8): array
    {
        $key = 'zv_bdepts_' . $brand->term_id . '_' . zv_lang() . '_v2';
        $cached = get_transient($key);
        if (is_array($cached)) {
            return $cached;
        }
        $ids = get_posts([
            'post_type' => 'product', 'post_status' => 'publish', 'fields' => 'ids', 'posts_per_page' => 400,
            'no_found_rows' => true, 'suppress_filters' => true,
            'tax_query' => [['taxonomy' => 'product_brand', 'field' => 'term_id', 'terms' => $brand->term_id]],
        ]);
        $out = [];
        if ($ids) {
            $total = count($ids);
            $terms = wp_get_object_terms($ids, 'product_cat', ['fields' => 'all_with_object_id']);
            $tally = [];
            foreach (is_wp_error($terms) ? [] : $terms as $t) {
                $anc = get_ancestors($t->term_id, 'product_cat');
                // A shelf is two levels under a pet (pet › department › shelf).
                if (count($anc) !== 2 || !isset(self::SPECIES[(int) end($anc)])) {
                    continue;
                }
                $tid = (int) $t->term_id;
                $tally[$tid] = $tally[$tid] ?? ['term' => $t, 'species' => self::SPECIES[(int) end($anc)], 'n' => 0, 'ids' => []];
                $tally[$tid]['n']++;
                $tally[$tid]['ids'][] = (int) $t->object_id;
            }
            $species = array_unique(array_column($tally, 'species'));
            usort($tally, static fn($a, $b) => $b['n'] <=> $a['n']);
            foreach ($tally as $row) {
                if ($row['n'] < 2 || $row['n'] >= $total && count($tally) > 1) {
                    continue;
                }
                $name = html_entity_decode($row['term']->name);
                if (count($species) > 1) {
                    $root = get_term(array_search($row['species'], self::SPECIES, true), 'product_cat');
                    $name .= ' ' . zv_for_pet($row['species'], $root instanceof WP_Term ? $root->name : '');
                }
                $out[] = ['slug' => $row['term']->slug, 'name' => $name, 'count' => $row['n'], 'ids' => $row['ids']];
                if (count($out) >= $n) {
                    break;
                }
            }
        }
        set_transient($key, $out, 6 * HOUR_IN_SECONDS);
        return $out;
    }

    public static function brand_count(): int
    {
        if (!taxonomy_exists('product_brand')) {
            return 0;
        }
        return (int) wp_count_terms(['taxonomy' => 'product_brand', 'hide_empty' => true]);
    }

    public static function product_count(): int
    {
        $c = wp_count_posts('product');
        return (int) ($c->publish ?? 0);
    }
}
