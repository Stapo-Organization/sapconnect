<?php
/**
 * Shared pieces: the product card, rails, the delivery chip, breadcrumbs.
 *
 * The card (one design everywhere) is the merge the owner asked for:
 * B's warm shell, A's information order (brand → name → sizes → price),
 * C's honest delivery promise, and a one-tap add that becomes a stepper.
 */

defined('ABSPATH') || exit;

/** The promise chip for a card: «⚡ خلال ساعتين» / «يوصلك اليوم» / «يصلك الأحد». */
function zv_chip(?array $chip): string
{
    if (!$chip || empty($chip['tier'])) {
        return '';
    }
    $tier = (string) $chip['tier'];
    if ($tier === 'express') {
        return '<span class="zv-chip zv-chip--express">' . zv_bolt(12) . esc_html(zv_t('خلال ساعتين', 'In 2 hours')) . '</span>';
    }
    $label = zv_clean_copy((string) ($chip['label'] ?? ''));
    if ($label === '') {
        return '';
    }
    $cls = $tier === 'same_day' ? 'zv-chip--day' : 'zv-chip--ship';
    return '<span class="zv-chip ' . $cls . '">' . zv_icon($tier === 'same_day' ? 'truck' : 'box', 13) . esc_html($label) . '</span>';
}

/** One merchandising badge, at most — urgency first. */
function zv_badge(?array $badge, array $hide = []): string
{
    if (!$badge || empty($badge['type']) || in_array($badge['type'], $hide, true)) {
        return '';
    }
    $map = ['low' => 'urgent', 'hot' => 'hot', 'new' => 'new'];
    if (!isset($map[$badge['type']])) {
        return '';
    }
    $label = zv_strip_emoji((string) ($badge['label'] ?? ''));
    return $label === '' ? '' : '<span class="zv-badge zv-badge--' . $map[$badge['type']] . '">' . esc_html($label) . '</span>';
}

/**
 * The product card.
 *
 * @param array $c   Zv_Catalog::card() data
 * @param array $opt hide_badges (string[]), eager (bool), list (string, tracking)
 */
function zv_card(array $c, array $opt = []): string
{
    $id      = (int) $c['id'];
    $url     = (string) ($c['url'] ?? get_permalink($id));
    $name    = (string) $c['name'];
    $instock = ($c['stock_status'] ?? 'instock') === 'instock';
    $is_var  = !empty($c['is_variable']);
    $thumb   = (string) ($c['gallery_thumb'] ?? $c['image'] ?? '');
    $full    = (string) ($c['image'] ?? $thumb);
    $brand   = is_array($c['brand'] ?? null) ? (string) ($c['brand']['name'] ?? '') : '';
    $price   = (float) ($c['price'] ?? 0);
    $regular = (float) ($c['regular_price'] ?? 0);
    $on_sale = !empty($c['on_sale']) && $regular > $price && $price > 0;
    $pct     = (int) ($c['discount_pct'] ?? 0);
    $sizes   = array_slice((array) ($c['sizes'] ?? []), 0, 3);
    $loading = !empty($opt['eager']) ? 'eager' : 'lazy';

    $srcset = $thumb && $full && $thumb !== $full ? ' srcset="' . esc_url($thumb) . ' 300w, ' . esc_url($full) . ' 600w" sizes="(max-width: 600px) 46vw, 240px"' : '';

    ob_start(); ?>
    <article class="zv-card<?php echo $instock ? '' : ' is-out'; ?><?php echo !empty($c['bundle']) ? ' is-bundle' : ''; ?>" data-pid="<?php echo $id; ?>">
        <div class="zv-card__top">
            <a class="zv-card__media" href="<?php echo esc_url($url); ?>" tabindex="-1" aria-hidden="true">
                <img src="<?php echo esc_url($thumb ?: $full); ?>"<?php echo $srcset; // phpcs:ignore ?> alt="" width="300" height="300" loading="<?php echo $loading; ?>" decoding="async">
            </a>
            <div class="zv-card__tags">
                <?php if ($on_sale && $pct >= 5) : ?><span class="zv-badge zv-badge--sale" dir="ltr">-<?php echo $pct; ?>%</span><?php endif; ?>
                <?php echo zv_badge($c['badge'] ?? null, (array) ($opt['hide_badges'] ?? [])); // phpcs:ignore ?>
            </div>
            <?php if (function_exists('zooboxi_fav_button')) : ?>
                <div class="zv-card__fav"><?php echo zooboxi_fav_button($id, 'loop'); // phpcs:ignore ?></div>
            <?php endif; ?>
        </div>
        <div class="zv-card__body">
            <?php if ($brand !== '') : ?><span class="zv-card__brand"><?php echo esc_html($brand); ?></span><?php endif; ?>
            <h3 class="zv-card__name"><a href="<?php echo esc_url($url); ?>"><?php echo esc_html($name); ?></a></h3>
            <?php if ($sizes) : ?><span class="zv-card__sizes"><?php echo esc_html(implode(' · ', $sizes)); ?></span><?php endif; ?>
            <?php echo $instock ? zv_chip($c['delivery_chip'] ?? null) : ''; // phpcs:ignore ?>
        </div>
        <div class="zv-card__foot">
            <div class="zv-card__price">
                <?php if (!empty($c['price_from']) || $is_var) : ?><span class="zv-card__from"><?php zv_e('يبدأ من', 'From'); ?></span><?php endif; ?>
                <?php echo zv_money($price, $on_sale ? 'is-sale' : ''); // phpcs:ignore ?>
                <?php if ($on_sale) : ?><s class="zv-card__was"><?php echo esc_html(zv_num($regular)); ?></s><?php endif; ?>
            </div>
            <?php if (!$instock) : ?>
                <span class="zv-card__na"><?php zv_e('غير متوفر', 'Sold out'); ?></span>
            <?php elseif ($is_var) : ?>
                <a class="zv-add zv-add--choose" href="<?php echo esc_url($url); ?>" aria-label="<?php echo esc_attr(sprintf(zv_t('اختر الحجم: %s', 'Choose size: %s'), $name)); ?>"><?php zv_e('اختر', 'Choose'); ?></a>
            <?php else : ?>
                <button type="button" class="zv-add" data-zv-add="<?php echo $id; ?>" aria-label="<?php echo esc_attr(sprintf(zv_t('أضف للسلة: %s', 'Add to cart: %s'), $name)); ?>"><?php echo zv_icon('plus', 20); // phpcs:ignore ?></button>
            <?php endif; ?>
        </div>
    </article>
    <?php
    return (string) ob_get_clean();
}

/** A titled row of cards; scrolls sideways on phones, wraps into a grid on desktop. */
function zv_rail(string $title, array $ids, array $opt = []): string
{
    // Rails merchandise; a sold-out product never takes a place in one.
    $cards = array_values(array_filter(Zv_Catalog::cards($ids), static fn($c) => ($c['stock_status'] ?? 'instock') === 'instock'));
    if (count($cards) < 2) {
        return '';
    }
    ob_start(); ?>
    <section class="zv-section zv-rail<?php echo !empty($opt['class']) ? ' ' . esc_attr($opt['class']) : ''; ?>">
        <div class="zv-section__head">
            <div>
                <h2 class="zv-h2"><?php echo esc_html($title); ?></h2>
                <?php if (!empty($opt['sub'])) : ?><p class="zv-section__sub"><?php echo esc_html($opt['sub']); ?></p><?php endif; ?>
            </div>
            <?php if (!empty($opt['more'])) : ?><a class="zv-more" href="<?php echo esc_url($opt['more']); ?>"><?php zv_e('عرض الكل', 'See all'); ?><?php echo zv_icon('more', 16); // phpcs:ignore ?></a><?php endif; ?>
        </div>
        <div class="zv-rail__track">
            <?php foreach ($cards as $i => $c) {
                echo zv_card($c, ['hide_badges' => (array) ($opt['hide_badges'] ?? []), 'eager' => !empty($opt['eager']) && $i < 4]); // phpcs:ignore
            } ?>
        </div>
    </section>
    <?php
    return (string) ob_get_clean();
}

/** Breadcrumbs: [[label, url|null], …] */
function zv_crumbs(array $items): string
{
    $out = '<nav class="zv-crumbs" aria-label="' . esc_attr(zv_t('مسار التصفح', 'Breadcrumb')) . '"><ol>';
    $last = count($items) - 1;
    foreach ($items as $i => [$label, $url]) {
        $out .= '<li>' . ($url && $i < $last ? '<a href="' . esc_url($url) . '">' . esc_html($label) . '</a>' : '<span aria-current="page">' . esc_html($label) . '</span>') . '</li>';
    }
    return $out . '</ol></nav>';
}

/** Payment marks from the store's own asset library. */
function zv_pay_marks(): string
{
    $base = content_url('uploads/zooboxi-assets/');
    $out = '';
    foreach (['mada' => 'مدى', 'applepay' => 'Apple Pay', 'stcpay' => 'STC Pay', 'visa' => 'Visa', 'mastercard' => 'Mastercard'] as $k => $alt) {
        $out .= '<span class="zv-pay"><img src="' . esc_url($base . 'pay-' . $k . '.svg') . '" alt="' . esc_attr($alt) . '" width="44" height="28" loading="lazy"></span>';
    }
    return $out;
}

/** A WooCommerce loop (related, up-sells, shortcodes) draws the same card. */
function zv_loop_card(): void
{
    global $product;
    if (!$product instanceof WC_Product) {
        return;
    }
    $c = Zv_Catalog::card($product->get_id());
    if ($c) {
        echo zv_card($c); // phpcs:ignore
    }
}

/* ══════════════════════════════════════════════════════════════
   LISTING UI — facets are plain links (crawlable, work without JS);
   zv.js swaps the results in place when it is there.
   ══════════════════════════════════════════════════════════════ */

/** The listing's base URL (no paging) with the current filters. */
function zv_listing_url(array $o, array $change = []): string
{
    $base = '';
    $term = get_queried_object();
    if ($term instanceof WP_Term) {
        $base = get_term_link($term);
    } elseif (is_search()) {
        $base = add_query_arg(['s' => get_search_query(false), 'post_type' => 'product'], home_url('/'));
    } else {
        $base = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/shop/');
    }
    $q = [];
    $shelf = array_key_exists('zb_cat', $change) ? (string) $change['zb_cat'] : (string) ($o['zb_cat'] ?? '');
    if ($shelf !== '') {
        $q['zb_cat'] = $shelf;
    }
    $f = $o['f'] ?? [];
    foreach ($change['f'] ?? [] as $facet => $vals) {
        $f[$facet] = $vals;
    }
    foreach ($f as $facet => $vals) {
        $vals = array_values(array_filter((array) $vals, 'strlen'));
        if ($vals) {
            $q['f_' . $facet] = implode(',', $vals);
        }
    }
    $min = array_key_exists('min_price', $change) ? $change['min_price'] : ($o['min_price'] ?? null);
    $max = array_key_exists('max_price', $change) ? $change['max_price'] : ($o['max_price'] ?? null);
    if ($min !== null) {
        $q['min_price'] = (int) floor((float) $min);
    }
    if ($max !== null) {
        $q['max_price'] = (int) ceil((float) $max);
    }
    $ord = $change['orderby'] ?? ($o['orderby'] ?? 'recommended');
    if ($ord !== 'recommended') {
        $q['orderby'] = $ord;
    }
    $exp = array_key_exists('express', $change) ? $change['express'] : !empty($o['express']);
    if ($exp) {
        $q['express'] = 1;
    }
    $pg = (int) ($change['pg'] ?? 1);
    if ($pg > 1) {
        $q['pg'] = $pg;
    }
    return add_query_arg(array_map('rawurlencode', $q), $base);
}

/** Toggle one facet value in the current selection. */
function zv_facet_toggle_url(array $o, string $facet, string $value): string
{
    $cur = array_values((array) ($o['f'][$facet] ?? []));
    $cur = in_array($value, $cur, true) ? array_values(array_diff($cur, [$value])) : array_merge($cur, [$value]);
    return zv_listing_url($o, ['f' => [$facet => $cur]]);
}

/** The facet column (desktop) / sheet (mobile). */
function zv_facets_html(array $o, ?array $facets): string
{
    $s = Zv_Scope::get();
    ob_start(); ?>
    <div class="zv-facets" data-zv-facets>
        <?php if ($s['express_open']) : ?>
            <a class="zv-toggle<?php echo !empty($o['express']) ? ' is-on' : ''; ?>" href="<?php echo esc_url(zv_listing_url($o, ['express' => empty($o['express'])])); ?>" data-zv-link role="switch" aria-checked="<?php echo !empty($o['express']) ? 'true' : 'false'; ?>">
                <span class="zv-toggle__txt"><?php echo zv_bolt(15); // phpcs:ignore ?><?php zv_e('يوصلك خلال ساعتين', 'Arrives in 2 hours'); ?></span>
                <span class="zv-toggle__knob" aria-hidden="true"></span>
            </a>
        <?php endif; ?>
        <?php if ($facets && !empty($facets['groups'])) :
            foreach ($facets['groups'] as $g) :
                $open = !empty($g['selected']) || in_array($g['key'], ['dept', 'brand', 'life', 'form'], true);
                $many = count($g['values']) > 7; ?>
                <details class="zv-facet" <?php echo $open ? 'open' : ''; ?>>
                    <summary><span><?php echo esc_html($g['label']); ?><?php if (!empty($g['selected'])) : ?> <em class="zv-facet__n"><?php echo (int) $g['selected']; ?></em><?php endif; ?></span><?php echo zv_icon('down', 18); // phpcs:ignore ?></summary>
                    <ul class="zv-facet__list<?php echo $many ? ' is-long' : ''; ?>">
                        <?php foreach ($g['values'] as $i => $v) :
                            $dead = (int) $v['count'] === 0 && empty($v['selected']); ?>
                            <li<?php echo $many && $i >= 7 && empty($v['selected']) ? ' class="is-more"' : ''; ?>>
                                <a class="zv-check<?php echo !empty($v['selected']) ? ' is-on' : ''; ?><?php echo $dead ? ' is-dead' : ''; ?>" href="<?php echo esc_url(zv_facet_toggle_url($o, $g['key'], (string) $v['key'])); ?>" data-zv-link rel="nofollow"<?php echo $dead ? ' aria-disabled="true" tabindex="-1"' : ''; ?> title="<?php echo esc_attr((string) ($v['note'] ?? '')); ?>">
                                    <span class="zv-check__box" aria-hidden="true"><?php echo zv_icon('check', 14); // phpcs:ignore ?></span>
                                    <span class="zv-check__label"><?php echo esc_html(zv_strip_emoji((string) $v['label'])); ?></span>
                                    <span class="zv-check__n"><?php echo (int) $v['count']; ?></span>
                                </a>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                    <?php if ($many) : ?><button type="button" class="zv-facet__more" data-zv-more><?php zv_e('عرض المزيد', 'Show more'); ?></button><?php endif; ?>
                </details>
            <?php endforeach;
        endif;
        if ($facets && !empty($facets['price']['buckets'])) :
            $sel = $facets['price']['selected'] ?? ['min' => null, 'max' => null]; ?>
            <details class="zv-facet" open>
                <summary><span><?php zv_e('السعر', 'Price'); ?></span><?php echo zv_icon('down', 18); // phpcs:ignore ?></summary>
                <ul class="zv-facet__list">
                    <?php foreach ($facets['price']['buckets'] as $b) :
                        $on = ($sel['min'] !== null || $sel['max'] !== null) && (float) $sel['min'] == (float) $b['min'] && (float) $sel['max'] == (float) $b['max'];
                        $url = $on ? zv_listing_url($o, ['min_price' => null, 'max_price' => null]) : zv_listing_url($o, ['min_price' => $b['min'], 'max_price' => $b['max']]); ?>
                        <li><a class="zv-check zv-check--radio<?php echo $on ? ' is-on' : ''; ?>" href="<?php echo esc_url($url); ?>" data-zv-link rel="nofollow"><span class="zv-check__box" aria-hidden="true"></span><span class="zv-check__label"><?php echo esc_html($b['label']); ?> <span class="zv-sar">﷼</span></span><span class="zv-check__n"><?php echo (int) $b['count']; ?></span></a></li>
                    <?php endforeach; ?>
                </ul>
            </details>
        <?php endif; ?>
    </div>
    <?php
    return (string) ob_get_clean();
}

/** Active filters as removable chips. */
function zv_active_chips(array $o, ?array $facets): string
{
    $chips = [];
    if ($facets && !empty($facets['groups'])) {
        foreach ($facets['groups'] as $g) {
            foreach ($g['values'] as $v) {
                if (!empty($v['selected'])) {
                    $chips[] = [zv_strip_emoji((string) $v['label']), zv_facet_toggle_url($o, $g['key'], (string) $v['key'])];
                }
            }
        }
    }
    if (($o['min_price'] ?? null) !== null || ($o['max_price'] ?? null) !== null) {
        $label = trim(($o['min_price'] !== null ? zv_num((float) $o['min_price']) : '0') . ' – ' . ($o['max_price'] !== null ? zv_num((float) $o['max_price']) : '∞'));
        $chips[] = [$label . ' ﷼', zv_listing_url($o, ['min_price' => null, 'max_price' => null])];
    }
    if (!empty($o['express'])) {
        $chips[] = [zv_t('خلال ساعتين', 'In 2 hours'), zv_listing_url($o, ['express' => false])];
    }
    if (!$chips) {
        return '';
    }
    $clear = zv_listing_url(['orderby' => $o['orderby'] ?? 'recommended', 'zb_cat' => $o['zb_cat'] ?? '']);
    $out = '<div class="zv-active">';
    foreach ($chips as [$label, $url]) {
        $out .= '<a class="zv-active__chip" href="' . esc_url($url) . '" data-zv-link rel="nofollow">' . esc_html($label) . zv_icon('close', 14) . '</a>';
    }
    return $out . '<a class="zv-active__clear" href="' . esc_url($clear) . '" data-zv-link rel="nofollow">' . esc_html(zv_t('مسح الكل', 'Clear all')) . '</a></div>';
}

/** Page links: « 1 2 … 9 » */
function zv_pager(array $o, int $page, int $pages): string
{
    if ($pages < 2) {
        return '';
    }
    $nums = array_unique(array_filter([1, $page - 1, $page, $page + 1, $pages], static fn($n) => $n >= 1 && $n <= $pages));
    sort($nums);
    $out = '<nav class="zv-pager" aria-label="' . esc_attr(zv_t('الصفحات', 'Pages')) . '">';
    if ($page > 1) {
        $out .= '<a class="zv-pager__step" href="' . esc_url(zv_listing_url($o, ['pg' => $page - 1])) . '" rel="prev" data-zv-link aria-label="' . esc_attr(zv_t('السابق', 'Previous')) . '">' . zv_icon('right', 18) . '</a>';
    }
    $prev = 0;
    foreach ($nums as $n) {
        if ($prev && $n > $prev + 1) {
            $out .= '<span class="zv-pager__gap">…</span>';
        }
        $out .= $n === $page
            ? '<span class="zv-pager__n is-on" aria-current="page">' . $n . '</span>'
            : '<a class="zv-pager__n" href="' . esc_url(zv_listing_url($o, ['pg' => $n])) . '" data-zv-link>' . $n . '</a>';
        $prev = $n;
    }
    if ($page < $pages) {
        $out .= '<a class="zv-pager__step" href="' . esc_url(zv_listing_url($o, ['pg' => $page + 1])) . '" rel="next" data-zv-link aria-label="' . esc_attr(zv_t('التالي', 'Next')) . '">' . zv_icon('left', 18) . '</a>';
    }
    return $out . '</nav>';
}

/**
 * A brand page's header: the brand's own banner beside its story, with the
 * promo pictures as two even squares (one size everywhere, never full-bleed).
 * Brands without a published boutique get the same frame with just the logo.
 */
function zv_brand_head(array $p, int $count): string
{
    $style = '';
    foreach (['accent' => '--b-accent', 'dark' => '--b-dark'] as $k => $var) {
        if ($p[$k] !== '') {
            $style .= $var . ':' . $p[$k] . ';';
        }
    }
    $hero = $p['hero'] !== '';
    $cls = 'zv-bhead' . ($hero ? '' : ' zv-bhead--plain') . ($hero && !$p['tiles'] ? ' zv-bhead--solo' : '');
    ob_start(); ?>
    <section class="<?php echo esc_attr($cls); ?>"<?php echo $style ? ' style="' . esc_attr($style) . '"' : ''; ?>>
        <div class="zv-bhead__copy">
            <?php if ($p['logo'] !== '') : ?><span class="zv-bhead__logo"><img src="<?php echo esc_url($p['logo']); ?>" alt="" width="160" height="64"></span><?php endif; ?>
            <h1 class="zv-bhead__name"><?php echo esc_html($p['name']); ?></h1>
            <?php if ($p['tagline'] !== '') : ?><p class="zv-bhead__tag"><?php echo esc_html($p['tagline']); ?></p><?php endif; ?>
            <?php if ($p['lead'] !== '') : ?><p class="zv-bhead__lead"><?php echo esc_html($p['lead']); ?></p><?php endif; ?>
            <ul class="zv-bhead__facts">
                <?php if ($p['country'] !== '') : ?><li><?php echo zv_icon('globe', 16); // phpcs:ignore ?><span><?php zv_e('من', 'From'); ?></span><strong><?php echo esc_html($p['country']); ?></strong></li><?php endif; ?>
                <?php if ($p['since'] !== '') : ?><li><?php echo zv_icon('calendar', 16); // phpcs:ignore ?><span><?php zv_e('منذ', 'Since'); ?></span><strong><?php echo esc_html($p['since']); ?></strong></li><?php endif; ?>
                <li><?php echo zv_icon('box', 16); // phpcs:ignore ?><strong><?php echo esc_html(zv_count($count, zv_t('منتج واحد', '1 product'), zv_t('منتجان', '2 products'), zv_t('منتجات', 'products'), zv_t('منتجاً', 'products'))); ?></strong><span><?php zv_e('في زوبوكسي', 'at Zooboxi'); ?></span></li>
            </ul>
            <?php if ($hero) : ?><a class="zv-btn zv-btn--primary" href="#zv-brand-products"><?php echo esc_html(sprintf(zv_t('تسوّق منتجات %s', 'Shop %s'), $p['name'])); ?></a><?php endif; ?>
        </div>
        <?php if ($hero) : ?>
            <div class="zv-bhead__media">
                <img class="zv-bhead__hero zb-brand-track" data-zb-zone="<?php echo esc_attr('brand:' . $p['slug'] . ':hero'); ?>" src="<?php echo esc_url($p['hero']); ?>" alt="<?php echo esc_attr($p['name']); ?>" width="1536" height="1024" fetchpriority="high" decoding="async">
                <?php foreach ($p['tiles'] as $i => $t) : ?>
                    <a class="zv-bhead__tile zb-brand-track" href="#zv-brand-products" data-zb-zone="<?php echo esc_attr('brand:tile' . ($i + 1)); ?>" aria-label="<?php echo esc_attr($t['label'] !== '' ? $t['label'] : $p['name']); ?>">
                        <img src="<?php echo esc_url($t['img']); ?>" alt="" width="1024" height="1024" loading="lazy" decoding="async">
                    </a>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
    <?php
    return (string) ob_get_clean();
}

/* ══════════════════════════════════════════════════════════════
   CHARACTERS — one figure, several poses from the same library,
   scaled so the head stays the same size when the pose changes.
   zv-motion.js acts them out (hop, wow, celebrate, breathing).
   ══════════════════════════════════════════════════════════════ */

/**
 * @param string $base  file of the resting pose (assets/img)
 * @param array  $poses name => [file, scale against the base width]
 * @param array  $opt   class, w, h (base intrinsic size), eager
 */
function zv_char(string $base, array $poses = [], array $opt = []): string
{
    $data = [];
    foreach ($poses as $name => [$file, $scale]) {
        $data[$name] = [zv_img($file), (float) $scale];
    }
    $img = '<img class="zv-char__pose is-on" data-pose="base" src="' . esc_url(zv_img($base)) . '" alt="" width="' . (int) ($opt['w'] ?? 360) . '" height="' . (int) ($opt['h'] ?? 360) . '"'
        . (!empty($opt['eager']) ? ' fetchpriority="high"' : ' loading="lazy"') . ' decoding="async">';
    return '<span class="zv-char' . (!empty($opt['class']) ? ' ' . esc_attr($opt['class']) : '') . '" data-zv-char'
        . ($data ? " data-poses='" . esc_attr(wp_json_encode($data, JSON_UNESCAPED_SLASHES)) . "'" : '')
        . (!empty($opt['who']) ? ' data-who="' . esc_attr($opt['who']) . '"' : '') . '>'
        . '<span class="zv-char__shadow"></span>'
        . '<span class="zv-char__move"><span class="zv-char__breath">' . $img . '</span></span>'
        . '</span>';
}

/** A sleeping character with its «z z z» (empty states). */
function zv_sleeper(string $file, int $w = 180): string
{
    return '<span class="zv-sleeper" aria-hidden="true"><img src="' . esc_url(zv_img($file)) . '" alt="" width="' . $w . '" height="' . $w . '" loading="lazy"><i>z</i><i>z</i><i>z</i></span>';
}

/** The pet characters of the «لمين تتسوّق» row, each with its surprised face. */
function zv_pet_char(string $species): string
{
    switch ($species) {
        case 'cat':
            return zv_char('pet-cat.webp', ['wow' => ['pet-cat-wow.webp', 0.95]], ['w' => 360, 'h' => 342, 'who' => 'cat']);
        case 'dog':
            return zv_char('pet-dog.webp', ['wow' => ['pet-dog-wow.webp', 0.78]], ['w' => 360, 'h' => 334, 'who' => 'dog']);
        case 'bird':
            return zv_char('pet-bird.webp', [], ['w' => 360, 'h' => 299, 'who' => 'bird']);
        default:
            return zv_char('pet-small.webp', [], ['w' => 360, 'h' => 340, 'who' => 'small']);
    }
}
