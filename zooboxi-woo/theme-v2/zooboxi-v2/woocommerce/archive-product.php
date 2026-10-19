<?php
/**
 * Product listings: the shop, every category, tags, brand pages (with the
 * brand's own header when the owner published one), and product search.
 *
 * One layout: a warm header band (B), the department chips, then the facet
 * column (A) beside the results with the delivery toggle and sort (C).
 */
defined('ABSPATH') || exit;
get_header();

$term = get_queried_object();
$term = $term instanceof WP_Term ? $term : null;
$o    = Zv_Catalog::request_options($term);
$L    = Zv_Catalog::listing($o);
$cards = Zv_Catalog::cards($L['ids']);
$species = $term && $term->taxonomy === 'product_cat' ? Zv_Catalog::species_of($term) : '';
$is_brand = $term && $term->taxonomy === 'product_brand';
$shop  = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/shop/');

// Title, crumbs, intro.
$crumbs = [[zv_t('الرئيسية', 'Home'), home_url('/')]];
if (is_search()) {
    $title = sprintf(zv_t('نتائج البحث عن «%s»', 'Results for “%s”'), get_search_query(false));
    $crumbs[] = [zv_t('البحث', 'Search'), null];
} elseif ($term) {
    $title = html_entity_decode($term->name);
    if ($term->taxonomy === 'product_cat') {
        foreach (Zv_Catalog::trail($term) as $t) {
            $crumbs[] = [html_entity_decode($t->name), get_term_link($t)];
        }
    } else {
        if ($is_brand) {
            $bpage = get_page_by_path('brands');
            if ($bpage) {
                $crumbs[] = [zv_t('الماركات', 'Brands'), get_permalink($bpage)];
            }
        }
        $crumbs[] = [$title, null];
    }
} else {
    $title = zv_t('كل المنتجات', 'All products');
    $crumbs[] = [$title, null];
}
$desc_full = $term && !$is_brand ? trim((string) term_description($term)) : '';
$desc_text = trim(wp_strip_all_tags($desc_full));
$intro = $desc_text !== '' ? wp_trim_words($desc_text, 26, '…') : '';

// Department chips: this term's children, else its siblings.
$chips = [];
if ($term && $term->taxonomy === 'product_cat') {
    $kids = get_terms(['taxonomy' => 'product_cat', 'parent' => $term->term_id, 'hide_empty' => true, 'orderby' => 'count', 'order' => 'DESC', 'number' => 14]);
    if (is_array($kids) && $kids) {
        foreach ($kids as $k) {
            $chips[] = [html_entity_decode($k->name), get_term_link($k), false];
        }
    } elseif ($term->parent) {
        $sibs = get_terms(['taxonomy' => 'product_cat', 'parent' => $term->parent, 'hide_empty' => true, 'orderby' => 'count', 'order' => 'DESC', 'number' => 14]);
        foreach (is_array($sibs) ? $sibs : [] as $k) {
            $chips[] = [html_entity_decode($k->name), get_term_link($k), $k->term_id === $term->term_id];
        }
    }
}
if ($is_brand) {
    $brand = Zv_Catalog::brand_profile($term);
    $title = $brand['name'];
    $all_url = zv_listing_url($o, ['zb_cat' => '', 'pg' => 1]);
    // Counts are what reaches this customer, the same scope the grid lists.
    $reach = array_flip(Zv_Catalog::base_ids(['brand' => $term->slug]));
    $brand_total = count($reach);
    $chips[] = [zv_t('الكل', 'All'), $all_url, $o['zb_cat'] === '', $brand_total];
    foreach (Zv_Catalog::brand_depts($term) as $d) {
        $n = count(array_filter((array) ($d['ids'] ?? []), static fn($id) => isset($reach[$id])));
        if ($n > 0 || $o['zb_cat'] === $d['slug']) {
            $chips[] = [$d['name'], add_query_arg('zb_cat', rawurlencode($d['slug']), get_term_link($term)), $o['zb_cat'] === $d['slug'], $n];
        }
    }
    if (count($chips) < 3) {
        $chips = [];
    }
    $picks = $L['page'] === 1 && $o['zb_cat'] === '' && empty($o['f']) && $o['min_price'] === null && $o['max_price'] === null
        ? Zv_Catalog::listing(['brand' => $term->slug, 'orderby' => 'popularity', 'per_page' => 10])['ids']
        : [];
}
$sorts = Zv_Catalog::sort_labels();
$tint  = $species ? zv_species_tint($species) : 'peach';
?>

<div class="zv-wrap">
    <?php echo zv_crumbs($crumbs); // phpcs:ignore ?>

    <?php if ($is_brand) :
        echo zv_brand_head($brand, $brand_total); // phpcs:ignore
    else : ?>
    <section class="zv-listhead zv-tint--<?php echo esc_attr($tint); ?>">
        <div class="zv-listhead__copy">
            <h1 class="zv-listhead__title"><?php echo esc_html($title); ?></h1>
            <p class="zv-listhead__meta">
                <?php echo esc_html(zv_count((int) $L['total'], zv_t('منتج واحد', '1 product'), zv_t('منتجان', '2 products'), zv_t('منتجات', 'products'), zv_t('منتجاً', 'products'))); ?>
                <?php $sc = Zv_Scope::get(); if ($sc['located'] && $sc['label'] !== '') : ?>
                    · <?php echo esc_html(sprintf(zv_t('يوصل إلى %s', 'deliver to %s'), $sc['label'])); ?>
                <?php endif; ?>
            </p>
            <?php if ($intro !== '' && empty($o['f']) && $L['page'] === 1) : ?><p class="zv-listhead__intro"><?php echo esc_html($intro); ?></p><?php endif; ?>
        </div>
        <?php if ($species) : ?>
            <img class="zv-listhead__art" src="<?php echo esc_url(zv_species_art($species)); ?>" alt="" width="200" height="200">
        <?php elseif (is_search()) : ?>
            <img class="zv-listhead__art" src="<?php echo esc_url(zv_img('cat-peek.webp')); ?>" alt="" width="240" height="160">
        <?php endif; ?>
    </section>
    <?php endif; ?>

    <?php if ($chips) : ?>
        <nav class="zv-depts" aria-label="<?php echo esc_attr(zv_t('الأقسام الفرعية', 'Sub-departments')); ?>">
            <?php foreach ($chips as $chip) :
                [$name, $url, $on] = $chip; ?>
                <a class="zv-chipbtn<?php echo $on ? ' is-on' : ''; ?>" href="<?php echo esc_url($url); ?>"<?php echo $on ? ' aria-current="page"' : ''; ?>><?php echo esc_html($name); ?><?php if (isset($chip[3])) : ?> <small><?php echo (int) $chip[3]; ?></small><?php endif; ?></a>
            <?php endforeach; ?>
        </nav>
    <?php endif; ?>

    <?php if ($is_brand) : ?>
        <?php if (!empty($picks)) {
            echo zv_rail(sprintf(zv_t('الأكثر طلباً من %s', 'Best sellers from %s'), $brand['name']), $picks, ['hide_badges' => ['hot']]); // phpcs:ignore
        } ?>
        <div class="zv-section zv-section__head zv-bsection" id="zv-brand-products">
            <div>
                <h2 class="zv-h2"><?php echo esc_html(sprintf(zv_t('كل منتجات %s', 'All %s products'), $brand['name'])); ?></h2>
                <p class="zv-section__sub"><?php echo esc_html(zv_count((int) $L['total'], zv_t('منتج واحد', '1 product'), zv_t('منتجان', '2 products'), zv_t('منتجات', 'products'), zv_t('منتجاً', 'products'))); ?><?php $sc = Zv_Scope::get(); if ($sc['located'] && $sc['label'] !== '') : ?> · <?php echo esc_html(sprintf(zv_t('يوصل إلى %s', 'deliver to %s'), $sc['label'])); ?><?php endif; ?></p>
            </div>
        </div>
    <?php endif; ?>

    <div class="zv-listing" data-zv-listing>
        <aside class="zv-listing__side" aria-label="<?php echo esc_attr(zv_t('الفلاتر', 'Filters')); ?>">
            <div class="zv-listing__sidehead zv-only-m">
                <h2><?php zv_e('الفلاتر', 'Filters'); ?></h2>
                <button type="button" class="zv-iconbtn" data-zv-filters-close aria-label="<?php echo esc_attr(zv_t('إغلاق', 'Close')); ?>"><?php echo zv_icon('close', 22); // phpcs:ignore ?></button>
            </div>
            <div data-zv-region="facets"><?php echo zv_facets_html($o, $L['facets']); // phpcs:ignore ?></div>
            <div class="zv-listing__sidefoot zv-only-m">
                <button type="button" class="zv-btn zv-btn--primary zv-btn--block" data-zv-filters-close><?php zv_e('عرض النتائج', 'Show results'); ?> (<span data-zv-region="count"><?php echo (int) $L['total']; ?></span>)</button>
            </div>
        </aside>

        <section class="zv-listing__main" aria-live="polite">
            <div class="zv-toolbar">
                <button type="button" class="zv-btn zv-btn--soft zv-only-m" data-zv-filters-open><?php echo zv_icon('filter', 18); // phpcs:ignore ?><?php zv_e('الفلاتر', 'Filters'); ?></button>
                <form class="zv-sort" method="get" action="<?php echo esc_url(zv_listing_url($o, ['orderby' => 'recommended'])); ?>" data-zv-sort>
                    <label>
                        <span class="zv-only-d"><?php zv_e('ترتيب حسب', 'Sort by'); ?></span>
                        <select name="orderby" aria-label="<?php echo esc_attr(zv_t('ترتيب حسب', 'Sort by')); ?>">
                            <?php foreach ($sorts as $k => $label) : ?>
                                <option value="<?php echo esc_attr($k); ?>" data-url="<?php echo esc_url(zv_listing_url($o, ['orderby' => $k])); ?>" <?php selected($L['orderby'], $k); ?>><?php echo esc_html($label); ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <noscript><button type="submit" class="zv-btn zv-btn--soft"><?php zv_e('ترتيب', 'Sort'); ?></button></noscript>
                </form>
            </div>

            <div data-zv-region="active"><?php echo zv_active_chips($o, $L['facets']); // phpcs:ignore ?></div>

            <div data-zv-region="results">
                <?php if ($cards) : ?>
                    <div class="zv-grid">
                        <?php foreach ($cards as $i => $c) {
                            echo zv_card($c, ['eager' => $i < 4, 'hide_badges' => $is_brand ? ['hot'] : []]); // phpcs:ignore
                        } ?>
                    </div>
                    <?php echo zv_pager($o, (int) $L['page'], (int) $L['pages']); // phpcs:ignore ?>
                <?php else : ?>
                    <div class="zv-empty zv-empty--page">
                        <?php echo zv_sleeper('dog-sleep.webp'); // phpcs:ignore ?>
                        <strong><?php echo !empty($o['f']) || $o['min_price'] !== null ? esc_html(zv_t('ما فيه منتجات بهالاختيارات', 'Nothing matches these filters')) : esc_html(zv_t('ما فيه منتجات توصل لموقعك هنا حالياً', 'Nothing here reaches your location right now')); ?></strong>
                        <?php if (!empty($L['facets']['relax'])) : ?>
                            <span><?php zv_e('جرّب تشيل واحد من هذي:', 'Try removing one of these:'); ?></span>
                            <div class="zv-active">
                                <?php foreach (array_slice($L['facets']['relax'], 0, 4) as $r) :
                                    $url = $r['group'] === 'price' ? zv_listing_url($o, ['min_price' => null, 'max_price' => null]) : zv_facet_toggle_url($o, $r['group'], (string) $r['value']); ?>
                                    <a class="zv-active__chip" href="<?php echo esc_url($url); ?>" data-zv-link><?php echo esc_html(zv_strip_emoji((string) $r['label'])); ?> (<?php echo (int) $r['count']; ?>)<?php echo zv_icon('close', 14); // phpcs:ignore ?></a>
                                <?php endforeach; ?>
                            </div>
                        <?php else : ?>
                            <a class="zv-btn zv-btn--primary" href="<?php echo esc_url($shop); ?>"><?php zv_e('تصفّح كل المنتجات', 'Browse all products'); ?></a>
                        <?php endif; ?>
                    </div>
                <?php endif; ?>
            </div>
        </section>
    </div>

    <?php if ($desc_full !== '' && $L['page'] === 1 && empty($o['f']) && mb_strlen($desc_text) > 180) : ?>
        <section class="zv-seo">
            <h2 class="zv-h3"><?php echo esc_html(sprintf(zv_t('عن %s', 'About %s'), $title)); ?></h2>
            <div class="zv-prose"><?php echo wp_kses_post($desc_full); ?></div>
        </section>
    <?php endif; ?>
</div>

<?php get_footer();
