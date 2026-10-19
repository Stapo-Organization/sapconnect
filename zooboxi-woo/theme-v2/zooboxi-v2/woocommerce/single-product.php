<?php
/**
 * Product page.
 *
 * Data: Zooboxi_Product_DTO::pdp() — the app's own product page payload
 * (variations purchasable HERE, the honest delivery plan, the structured
 * «قصة المنتج», frequently-bought-together). The page adds the web's needs:
 * price per kilo, a real add-to-cart form, and WooCommerce's structured data.
 */
defined('ABSPATH') || exit;
get_header();

while (have_posts()) :
    the_post();
    global $product;
    $product = wc_get_product(get_the_ID());
    if (!$product) {
        continue;
    }
    $id  = $product->get_id();
    $pdp = class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::pdp($id) : null;
    $s   = Zv_Scope::get();

    // ── Identity
    $name   = $product->get_name();
    $brandD = $pdp['brand_detail'] ?? ($pdp['brand'] ?? null);
    $brandL = '';
    if (!empty($brandD['slug']) && taxonomy_exists('product_brand')) {
        $bt = get_term_by('slug', $brandD['slug'], 'product_brand');
        $brandL = $bt ? get_term_link($bt) : '';
    }

    // ── Photos: the real gallery at full size; the DTO's fallback when none.
    $photos = [];
    foreach (array_filter(array_merge([$product->get_image_id()], $product->get_gallery_image_ids())) as $aid) {
        $photos[] = ['src' => wp_get_attachment_image_url($aid, 'woocommerce_single'), 'full' => wp_get_attachment_image_url($aid, 'full'), 'thumb' => wp_get_attachment_image_url($aid, 'woocommerce_gallery_thumbnail')];
    }
    if (!$photos) {
        $u = $pdp['image'] ?? (class_exists('Zooboxi_Product_DTO') ? Zooboxi_Product_DTO::image_url($product, 'woocommerce_single') : wc_placeholder_img_src());
        $photos[] = ['src' => $u, 'full' => $u, 'thumb' => $u];
    }

    // ── Buying: options purchasable for THIS customer, with price per kilo.
    $is_var   = $product->is_type('variable');
    $vars     = $pdp['variations'] ?? ['attributes' => [], 'list' => []];
    $variants = [];
    foreach ((array) ($vars['list'] ?? []) as $v) {
        if (empty($v['in_stock'])) {
            continue;
        }
        $labels = [];
        foreach ((array) $v['attributes'] as $ak => $slug) {
            foreach ((array) ($vars['attributes'] ?? []) as $a) {
                if ('attribute_' . $a['slug'] === $ak) {
                    foreach ($a['options'] as $op) {
                        if ($op['slug'] === $slug) {
                            $labels[] = $op['label'];
                        }
                    }
                }
            }
        }
        $label = implode(' · ', $labels);
        $g = Zv_Catalog::grams($label);
        $units = max(1, (int) ($v['units'] ?? 1));
        $variants[] = [
            'id'      => (int) $v['variation_id'],
            'attrs'   => (array) $v['attributes'],
            'label'   => $label,
            'price'   => (float) $v['price'],
            'regular' => (float) $v['regular_price'],
            'max'     => (int) ($v['max_qty'] ?? 99),
            'units'   => $units,
            'per_kg'  => $g > 0 ? (float) $v['price'] / ($g * $units / 1000) : 0,
            'image'   => (string) ($v['image'] ?? ''),
        ];
    }
    // WooCommerce lists a variation as available only when its product_visibility
    // term agrees with its stock; hundreds of in-stock sizes still carry a stale
    // «outofstock» term, so the list came back empty while the card (which reads
    // the real stock) offered them. Read the real stock here too.
    if ($is_var && !$variants) {
        $names = [];
        foreach ((array) ($vars['attributes'] ?? []) as $a) {
            foreach ((array) $a['options'] as $op) {
                $names['attribute_' . $a['slug']][$op['slug']] = $op['label'];
            }
        }
        foreach ($product->get_children() as $vid) {
            $v = wc_get_product($vid);
            if (!$v || $v->get_status() !== 'publish' || !$v->is_purchasable() || !$v->is_in_stock() || (float) $v->get_price() <= 0) {
                continue;
            }
            $attrs = array_map('strval', $v->get_variation_attributes());
            $labels = [];
            foreach ($attrs as $ak => $slug) {
                $labels[] = $names[$ak][$slug] ?? (taxonomy_exists(substr($ak, 10)) && ($t = get_term_by('slug', $slug, substr($ak, 10))) ? $t->name : $slug);
            }
            $label = implode(' · ', array_filter($labels));
            $g = Zv_Catalog::grams($label);
            $units = class_exists('Zooboxi_Units') ? max(1, (int) Zooboxi_Units::for_id($vid)) : 1;
            $p = (float) wc_get_price_to_display($v);
            $variants[] = [
                'id'      => (int) $vid,
                'attrs'   => $attrs,
                'label'   => $label,
                'price'   => $p,
                'regular' => (float) wc_get_price_to_display($v, ['price' => $v->get_regular_price()]),
                'max'     => $v->get_max_purchase_quantity() > 0 ? (int) $v->get_max_purchase_quantity() : 99,
                'units'   => $units,
                'per_kg'  => $g > 0 ? $p / ($g * $units / 1000) : 0,
                'image'   => $v->get_image_id() ? (string) wp_get_attachment_image_url($v->get_image_id(), 'woocommerce_single') : '',
            ];
        }
    }
    usort($variants, static fn($a, $b) => $a['price'] <=> $b['price']);
    $best_kg = 0;
    $kgs = array_filter(array_column($variants, 'per_kg'));
    if (count($kgs) > 1) {
        $best_kg = min($kgs);
    }
    $chosen = $variants[0] ?? null;
    $instock = $is_var ? (bool) $variants : ($product->is_in_stock() && (($pdp['delivery']['reachable_total'] ?? 1) > 0 || !$s['located']));
    $price   = $chosen ? $chosen['price'] : (float) wc_get_price_to_display($product);
    $regular = $chosen ? $chosen['regular'] : (float) wc_get_price_to_display($product, ['price' => $product->get_regular_price()]);
    $on_sale = $regular > $price && $price > 0;
    $simple_g = $is_var ? 0 : Zv_Catalog::grams($name);
    $per_kg = $chosen ? $chosen['per_kg'] : ($simple_g > 0 ? $price / ($simple_g / 1000) : 0);
    $max    = $chosen ? $chosen['max'] : (int) ($product->get_max_purchase_quantity() > 0 ? $product->get_max_purchase_quantity() : 99);

    // ── Crumbs
    $crumbs = [[zv_t('الرئيسية', 'Home'), home_url('/')]];
    $cat = Zv_Catalog::primary_category($id);
    if ($cat) {
        foreach (Zv_Catalog::trail($cat) as $t) {
            $crumbs[] = [html_entity_decode($t->name), get_term_link($t)];
        }
    }
    $crumbs[] = [$name, null];

    $story = is_array($pdp['story'] ?? null) ? $pdp['story'] : null;
    $chips = [];
    foreach ((array) ($pdp['attributes'] ?? []) as $a) {
        if (in_array($a['label'] ?? '', ['المرحلة العمرية', 'ميزة صحية'], true) && !empty($a['value'])) {
            $chips[] = $a['value'];
        }
    }

    // Notices (e.g. «سلتك من متجر زوبكسي…» after a refused add) sit inside the page gutter.
    echo '<div class="zv-wrap zv-pdp-notices">';
    do_action('woocommerce_before_single_product');
    echo '</div>';
    if (function_exists('WC') && WC()->structured_data) {
        WC()->structured_data->generate_product_data($product);
    }
    ?>
    <div class="zv-wrap zv-pdp" data-zv-pdp="<?php echo (int) $id; ?>">
        <?php echo zv_crumbs($crumbs); // phpcs:ignore ?>

        <div class="zv-pdp__top">
            <section class="zv-gallery" aria-label="<?php echo esc_attr(zv_t('صور المنتج', 'Product photos')); ?>" data-zv-gallery>
                <div class="zv-gallery__main">
                    <img src="<?php echo esc_url($photos[0]['src']); ?>" data-full="<?php echo esc_url($photos[0]['full']); ?>" alt="<?php echo esc_attr($name); ?>" width="600" height="600" fetchpriority="high" data-zv-gallery-main>
                    <div class="zv-gallery__tags">
                        <?php if ($on_sale) : ?><span class="zv-badge zv-badge--sale" dir="ltr">-<?php echo (int) round((1 - $price / $regular) * 100); ?>%</span><?php endif; ?>
                        <?php echo zv_badge($pdp['badge'] ?? null); // phpcs:ignore ?>
                    </div>
                    <?php if (function_exists('zooboxi_fav_button')) : ?><div class="zv-gallery__fav"><?php echo zooboxi_fav_button($id, 'loop'); // phpcs:ignore ?></div><?php endif; ?>
                </div>
                <?php if (count($photos) > 1) : ?>
                    <div class="zv-gallery__thumbs">
                        <?php foreach ($photos as $i => $ph) : ?>
                            <button type="button" class="zv-gallery__thumb<?php echo $i === 0 ? ' is-on' : ''; ?>" data-src="<?php echo esc_url($ph['src']); ?>" data-full="<?php echo esc_url($ph['full']); ?>" aria-label="<?php echo esc_attr(sprintf(zv_t('صورة %d', 'Photo %d'), $i + 1)); ?>"><img src="<?php echo esc_url($ph['thumb']); ?>" alt="" width="80" height="80" loading="lazy"></button>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
            </section>

            <section class="zv-buybox">
                <div class="zv-buybox__chips">
                    <?php if (!empty($brandD['name'])) : ?>
                        <?php if ($brandL) : ?><a class="zv-tag zv-tag--brand" href="<?php echo esc_url($brandL); ?>"><?php echo esc_html($brandD['name']); ?></a><?php else : ?><span class="zv-tag zv-tag--brand"><?php echo esc_html($brandD['name']); ?></span><?php endif; ?>
                    <?php endif; ?>
                    <?php foreach (array_slice($chips, 0, 2) as $ch) : ?><span class="zv-tag"><?php echo esc_html($ch); ?></span><?php endforeach; ?>
                </div>
                <h1 class="zv-pdp__title"><?php echo esc_html($name); ?></h1>

                <div class="zv-pdp__price" data-zv-price>
                    <?php echo zv_money($price, $on_sale ? 'is-sale' : ''); // phpcs:ignore ?>
                    <?php if ($on_sale) : ?><s class="zv-card__was"><?php echo esc_html(zv_num($regular)); ?></s><?php endif; ?>
                    <span class="zv-pdp__unit" data-zv-perkg><?php echo $per_kg > 0 ? esc_html(sprintf(zv_t('%s ﷼ للكيلو', '%s SAR/kg'), zv_num($per_kg))) : ''; ?></span>
                    <span class="zv-pdp__vat"><?php zv_e('شامل الضريبة', 'VAT included'); ?></span>
                </div>

                <form class="zv-buy" method="post" action="<?php echo esc_url($product->get_permalink()); ?>" data-zv-buy enctype="multipart/form-data">
                    <?php if ($is_var && $variants) : ?>
                        <fieldset class="zv-opts">
                            <legend><?php echo esc_html($vars['attributes'][0]['label'] ?? zv_t('الحجم', 'Size')); ?>: <strong data-zv-opt-label><?php echo esc_html($chosen['label']); ?></strong></legend>
                            <div class="zv-opts__grid">
                                <?php foreach ($variants as $i => $v) : ?>
                                    <label class="zv-opt<?php echo $i === 0 ? ' is-on' : ''; ?>">
                                        <input type="radio" name="zv_variant" value="<?php echo (int) $v['id']; ?>" <?php checked($i, 0); ?>
                                            data-price="<?php echo esc_attr((string) $v['price']); ?>" data-regular="<?php echo esc_attr((string) $v['regular']); ?>"
                                            data-max="<?php echo (int) $v['max']; ?>" data-perkg="<?php echo esc_attr((string) round($v['per_kg'], 2)); ?>"
                                            data-label="<?php echo esc_attr($v['label']); ?>" data-image="<?php echo esc_url($v['image']); ?>"
                                            data-attrs="<?php echo esc_attr(wp_json_encode($v['attrs'])); ?>">
                                        <span class="zv-opt__name"><?php echo esc_html($v['label']); ?></span>
                                        <span class="zv-opt__price"><?php echo zv_money($v['price']); // phpcs:ignore ?></span>
                                        <?php if ($v['per_kg'] > 0) : ?><span class="zv-opt__kg"><?php echo esc_html(sprintf(zv_t('%s ﷼ للكيلو', '%s/kg'), zv_num($v['per_kg']))); ?></span><?php endif; ?>
                                        <?php if ($best_kg > 0 && abs($v['per_kg'] - $best_kg) < 0.01) : ?><span class="zv-opt__best"><?php zv_e('الأوفر', 'Best value'); ?></span><?php endif; ?>
                                    </label>
                                <?php endforeach; ?>
                            </div>
                            <?php
                            $all_opts = count((array) ($vars['attributes'][0]['options'] ?? []));
                            if ($all_opts > count($variants)) : ?>
                                <p class="zv-opts__note"><?php echo zv_icon('info', 16); // phpcs:ignore ?><?php zv_e('بعض الأحجام غير متوفرة لموقعك حالياً', 'Some sizes are not available at your location right now'); ?></p>
                            <?php endif; ?>
                        </fieldset>
                        <input type="hidden" name="add-to-cart" value="<?php echo (int) $id; ?>">
                        <input type="hidden" name="product_id" value="<?php echo (int) $id; ?>">
                        <input type="hidden" name="variation_id" value="<?php echo (int) $chosen['id']; ?>" data-zv-vid>
                        <?php foreach ($chosen['attrs'] as $ak => $av) : ?><input type="hidden" name="<?php echo esc_attr($ak); ?>" value="<?php echo esc_attr($av); ?>" data-zv-attr="<?php echo esc_attr($ak); ?>"><?php endforeach; ?>
                    <?php else : ?>
                        <input type="hidden" name="add-to-cart" value="<?php echo (int) $id; ?>">
                    <?php endif; ?>

                    <?php if ($instock) : ?>
                        <div class="zv-buy__row">
                            <div class="zv-step zv-step--lg" data-max="<?php echo (int) $max; ?>" data-zv-qty>
                                <button type="button" class="zv-step__btn" data-step="1" aria-label="<?php echo esc_attr(zv_t('زيادة', 'More')); ?>"><?php echo zv_icon('plus', 18); // phpcs:ignore ?></button>
                                <input class="zv-step__n" type="number" name="quantity" value="1" min="1" max="<?php echo (int) $max; ?>" inputmode="numeric" aria-label="<?php echo esc_attr(zv_t('الكمية', 'Quantity')); ?>">
                                <button type="button" class="zv-step__btn" data-step="-1" aria-label="<?php echo esc_attr(zv_t('إنقاص', 'Less')); ?>"><?php echo zv_icon('minus', 18); // phpcs:ignore ?></button>
                            </div>
                            <button type="submit" class="zv-btn zv-btn--primary zv-btn--lg zv-buy__add" data-zv-add-form><?php echo zv_icon('bag', 20); // phpcs:ignore ?><?php zv_e('أضف للسلة', 'Add to cart'); ?></button>
                        </div>
                        <button type="submit" name="zv_buy_now" value="1" class="zv-btn zv-btn--sun zv-btn--lg zv-btn--block" data-zv-buy-now><?php zv_e('اشترِ الآن', 'Buy now'); ?></button>
                    <?php else : ?>
                        <div class="zv-oos">
                            <strong><?php echo $s['located'] ? esc_html(zv_t('غير متوفر للتوصيل إلى موقعك حالياً', 'Not deliverable to your location right now')) : esc_html(zv_t('غير متوفر حالياً', 'Currently unavailable')); ?></strong>
                            <?php if (!empty($pdp['substitutes'])) : ?><a href="#zv-subs" class="zv-more"><?php zv_e('شوف البدائل', 'See alternatives'); ?><?php echo zv_icon('more', 16); // phpcs:ignore ?></a><?php endif; ?>
                        </div>
                    <?php endif; ?>
                </form>

                <?php // ── Delivery promise: tiers, never a branch name.
                $plan = $pdp['delivery'] ?? null; ?>
                <section class="zv-ship" aria-label="<?php echo esc_attr(zv_t('التوصيل', 'Delivery')); ?>">
                    <div class="zv-ship__to">
                        <?php echo zv_icon('pin', 18); // phpcs:ignore ?>
                        <span><?php echo $s['located'] && $s['label'] !== '' ? esc_html(sprintf(zv_t('التوصيل إلى %s', 'Delivering to %s'), $s['label'])) : esc_html(zv_t('حدّد موقعك لنعرض لك موعد التوصيل', 'Set your location to see delivery times')); ?></span>
                        <button type="button" class="zv-linkbtn" data-zv-open="location"><?php echo $s['located'] ? esc_html(zv_t('تغيير', 'Change')) : esc_html(zv_t('حدّد', 'Set')); ?></button>
                    </div>
                    <?php if ($s['located'] && $plan && !empty($plan['tiers'])) : ?>
                        <ul class="zv-ship__tiers">
                            <?php foreach ($plan['tiers'] as $t) :
                                $tier = (string) ($t['tier'] ?? '');
                                if ($tier === 'express') {
                                    $head = zv_t('إكسبريس — يوصلك خلال ساعتين', 'Express — within 2 hours');
                                    $icon = zv_bolt(20);
                                } elseif ($tier === 'same_day') {
                                    $head = sprintf(zv_t('يوصلك %s', 'Arrives %s'), (string) ($t['relative_label'] ?? zv_t('غدًا', 'tomorrow')));
                                    $icon = zv_icon('truck', 20);
                                } else {
                                    $head = sprintf(zv_t('يصلك %s', 'Arrives %s'), (string) (($t['date_label'] ?? '') ?: ($t['relative_label'] ?? '')));
                                    $icon = zv_icon('box', 20);
                                }
                                $fee = (float) ($t['fee'] ?? 0); ?>
                                <li class="zv-ship__tier zv-ship__tier--<?php echo esc_attr($tier); ?>">
                                    <span class="zv-ship__ic"><?php echo $icon; // phpcs:ignore ?></span>
                                    <span class="zv-ship__txt"><strong><?php echo esc_html(zv_clean_copy($head)); ?></strong>
                                        <span><?php echo $fee > 0 ? wp_kses_post(sprintf(zv_t('رسوم التوصيل %s', 'Delivery %s'), zv_money($fee))) : esc_html(zv_t('توصيل مجاني', 'Free delivery')); ?></span>
                                    </span>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    <?php endif; ?>
                    <ul class="zv-ship__trust">
                        <li><?php echo zv_icon('shield', 18); // phpcs:ignore ?><?php zv_e('أصلي 100٪', '100% genuine'); ?></li>
                        <li><?php echo zv_icon('return', 18); // phpcs:ignore ?><?php zv_e('إرجاع خلال 14 يوماً', '14-day returns'); ?></li>
                        <li><?php echo zv_icon('card', 18); // phpcs:ignore ?><?php zv_e('مدى · Apple Pay · STC Pay', 'mada · Apple Pay · STC Pay'); ?></li>
                    </ul>
                </section>

                <?php if (!empty($pdp['bundle']['components'])) : ?>
                    <section class="zv-bundle">
                        <h2 class="zv-h3"><?php zv_e('محتويات البكج', 'In this bundle'); ?></h2>
                        <ul>
                            <?php foreach ($pdp['bundle']['components'] as $bc) : ?>
                                <li>
                                    <img src="<?php echo esc_url((string) $bc['image']); ?>" alt="" width="56" height="56" loading="lazy">
                                    <span><a href="<?php echo esc_url(get_permalink((int) $bc['id'])); ?>"><?php echo esc_html($bc['name']); ?></a><?php if (!empty($bc['weight_label'])) : ?> <small><?php echo esc_html($bc['weight_label']); ?></small><?php endif; ?></span>
                                    <strong>× <?php echo (int) $bc['qty']; ?></strong>
                                    <?php if (($bc['role'] ?? '') === 'gift') : ?><em class="zv-badge zv-badge--gift"><?php zv_e('هدية', 'Gift'); ?></em><?php endif; ?>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                    </section>
                <?php endif; ?>
            </section>
        </div>

        <?php // ── The product's story ──────────────────────────────────── ?>
        <div class="zv-pdp__story">
            <?php if ($story && (!empty($story['highlights']) || !empty($story['facts']))) : ?>
                <section class="zv-why">
                    <h2 class="zv-h2"><?php echo esc_html(sprintf(zv_t('ليش يناسب %s؟', 'Why it suits your %s'), ['cat' => zv_t('قطتك', 'cat'), 'dog' => zv_t('كلبك', 'dog'), 'bird' => zv_t('طيرك', 'bird'), 'small' => zv_t('أليفك', 'pet')][$story['species'] ?? ''] ?? zv_t('أليفك', 'pet'))); ?></h2>
                    <?php if (!empty($story['facts'])) : ?>
                        <ul class="zv-facts">
                            <?php foreach (array_slice($story['facts'], 0, 4) as $f) : ?>
                                <li><strong><?php echo esc_html(zv_strip_emoji((string) $f['value'])); ?></strong><span><?php echo esc_html((string) $f['label']); ?></span></li>
                            <?php endforeach; ?>
                        </ul>
                    <?php endif; ?>
                    <?php if (!empty($story['highlights'])) : ?>
                        <ul class="zv-highlights">
                            <?php foreach (array_slice($story['highlights'], 0, 4) as $h) : ?>
                                <li><?php echo zv_icon('check', 18); // phpcs:ignore ?><span><strong><?php echo esc_html(zv_strip_emoji((string) ($h['title'] ?? ''))); ?></strong> <?php echo esc_html(zv_strip_emoji((string) ($h['text'] ?? ''))); ?></span></li>
                            <?php endforeach; ?>
                        </ul>
                    <?php endif; ?>
                </section>
            <?php endif; ?>

            <section class="zv-accordion">
                <?php if ($story && !empty($story['sections'])) :
                    foreach ($story['sections'] as $si => $sec) :
                        if ($sec['key'] === 'features' && !empty($story['highlights'])) {
                            continue; // already shown above
                        }
                        $stitle = zv_strip_emoji((string) ($sec['title'] ?: zv_t('الوصف', 'Description'))); ?>
                        <details class="zv-acc" <?php echo $si === 0 ? 'open' : ''; ?>>
                            <summary><h2><?php echo esc_html($stitle); ?></h2><?php echo zv_icon('down', 20); // phpcs:ignore ?></summary>
                            <div class="zv-acc__body zv-prose">
                                <?php if ($sec['key'] === 'feeding' && !empty($story['feeding']['rows'])) : ?>
                                    <div class="zv-table-wrap"><table class="zv-table">
                                        <thead><tr><?php foreach ((array) $story['feeding']['headers'] as $hh) : ?><th><?php echo esc_html((string) $hh); ?></th><?php endforeach; ?></tr></thead>
                                        <tbody><?php foreach ($story['feeding']['rows'] as $r) : ?><tr><th><?php echo esc_html((string) $r['label']); ?></th><?php foreach ((array) $r['cells'] as $cell) : ?><td><?php echo esc_html((string) $cell); ?></td><?php endforeach; ?></tr><?php endforeach; ?></tbody>
                                    </table></div>
                                <?php endif; ?>
                                <?php if ($sec['key'] === 'ingredients' && !empty($story['composition']['items'])) : ?>
                                    <ul class="zv-ingredients">
                                        <?php foreach ($story['composition']['items'] as $ing) : ?>
                                            <li><span><?php echo esc_html((string) $ing['name']); ?></span><?php if ($ing['pct'] !== null) : ?><strong><?php echo esc_html((string) $ing['pct']); ?>٪</strong><?php endif; ?><?php if (!empty($ing['detail'])) : ?><small><?php echo esc_html((string) $ing['detail']); ?></small><?php endif; ?></li>
                                        <?php endforeach; ?>
                                    </ul>
                                <?php else :
                                    foreach ((array) $sec['blocks'] as $b) :
                                        if ($sec['key'] === 'feeding' && !empty($story['feeding']['rows']) && $b['type'] === 'table') {
                                            continue;
                                        }
                                        if ($b['type'] === 'p') : ?>
                                            <p><?php echo esc_html(zv_strip_emoji((string) $b['text'])); ?></p>
                                        <?php elseif ($b['type'] === 'list') : ?>
                                            <?php if (!empty($b['lead'])) : ?><p><?php echo esc_html(zv_strip_emoji((string) $b['lead'])); ?></p><?php endif; ?>
                                            <<?php echo !empty($b['ordered']) ? 'ol' : 'ul'; ?>>
                                                <?php foreach ((array) $b['items'] as $it) :
                                                    $it_t = is_array($it) ? (string) ($it['title'] ?? '') : '';
                                                    $it_x = is_array($it) ? (string) ($it['text'] ?? '') : (string) $it; ?>
                                                    <li><?php if ($it_t !== '') : ?><strong><?php echo esc_html(zv_strip_emoji($it_t)); ?>:</strong> <?php endif; ?><?php echo esc_html(zv_strip_emoji($it_x)); ?></li>
                                                <?php endforeach; ?>
                                            </<?php echo !empty($b['ordered']) ? 'ol' : 'ul'; ?>>
                                        <?php elseif ($b['type'] === 'table') : ?>
                                            <div class="zv-table-wrap"><table class="zv-table">
                                                <?php if (!empty($b['headers'])) : ?><thead><tr><?php foreach ((array) $b['headers'] as $hh) : ?><th><?php echo esc_html((string) $hh); ?></th><?php endforeach; ?></tr></thead><?php endif; ?>
                                                <tbody><?php foreach ((array) $b['rows'] as $r) : ?><tr><?php foreach ((array) $r as $cell) : ?><td><?php echo esc_html(is_array($cell) ? implode(' ', $cell) : (string) $cell); ?></td><?php endforeach; ?></tr><?php endforeach; ?></tbody>
                                            </table></div>
                                        <?php endif;
                                    endforeach;
                                endif; ?>
                            </div>
                        </details>
                    <?php endforeach;
                else :
                    $desc = $product->get_description(); ?>
                    <?php if (trim(wp_strip_all_tags($desc)) !== '') : ?>
                        <details class="zv-acc" open>
                            <summary><h2><?php zv_e('الوصف', 'Description'); ?></h2><?php echo zv_icon('down', 20); // phpcs:ignore ?></summary>
                            <div class="zv-acc__body zv-prose"><?php echo wp_kses_post(wpautop(zv_strip_emoji($desc))); ?></div>
                        </details>
                    <?php endif; ?>
                <?php endif; ?>

                <?php if (!empty($pdp['attributes'])) : ?>
                    <details class="zv-acc">
                        <summary><h2><?php zv_e('المواصفات', 'Specifications'); ?></h2><?php echo zv_icon('down', 20); // phpcs:ignore ?></summary>
                        <div class="zv-acc__body">
                            <dl class="zv-specs">
                                <?php foreach ($pdp['attributes'] as $a) : ?>
                                    <div><dt><?php echo esc_html((string) $a['label']); ?></dt><dd><?php echo esc_html((string) $a['value']); ?></dd></div>
                                <?php endforeach; ?>
                                <?php if ($product->get_sku()) : ?><div><dt><?php zv_e('الباركود', 'Barcode'); ?></dt><dd dir="ltr"><?php echo esc_html($product->get_sku()); ?></dd></div><?php endif; ?>
                            </dl>
                        </div>
                    </details>
                <?php endif; ?>

                <details class="zv-acc">
                    <summary><h2><?php zv_e('التوصيل والإرجاع', 'Delivery & returns'); ?></h2><?php echo zv_icon('down', 20); // phpcs:ignore ?></summary>
                    <div class="zv-acc__body zv-prose">
                        <p><?php zv_e('إكسبريس خلال ساعتين داخل نطاق التوصيل في الرياض أثناء ساعات العمل، والتوصيل العادي لبقية الأحياء، والشحن لكل مدن المملكة. يظهر موعد التوصيل الدقيق ورسومه في السلة قبل الدفع.', 'Express within two hours inside the Riyadh delivery zone during opening hours; standard delivery elsewhere; shipping across Saudi Arabia. The exact time and fee show in the cart before you pay.'); ?></p>
                        <?php $rp = get_page_by_path('return-policy'); if ($rp) : ?><p><a href="<?php echo esc_url(get_permalink($rp)); ?>"><?php zv_e('سياسة الاستبدال والإرجاع', 'Returns policy'); ?></a></p><?php endif; ?>
                    </div>
                </details>

                <?php
                // Reviews: only customers who bought the product can write one, so every star is real.
                $zv_rcount  = (int) $product->get_review_count();
                $zv_ravg    = (float) $product->get_average_rating();
                $zv_reviews = $zv_rcount ? get_comments(['post_id' => $id, 'status' => 'approve', 'type' => 'review', 'number' => 20]) : [];
                $zv_uid     = get_current_user_id();
                $zv_bought  = $zv_uid && function_exists('wc_customer_bought_product') && wc_customer_bought_product('', $zv_uid, $id);
                $zv_mine    = $zv_bought ? get_comments(['post_id' => $id, 'user_id' => $zv_uid, 'type' => 'review', 'count' => true, 'status' => 'all']) : 0;
                ?>
                <details class="zv-acc zv-reviews" id="reviews" <?php echo isset($_GET['review']) ? 'open' : ''; // phpcs:ignore ?>>
                    <summary><h2><?php zv_e('تقييمات العملاء', 'Customer reviews'); ?><?php if ($zv_rcount) : ?> <span class="zv-reviews__sum"><span class="zv-stars" style="--r:<?php echo esc_attr((string) $zv_ravg); ?>" aria-hidden="true"></span> <?php echo esc_html(number_format($zv_ravg, 1)); ?> (<?php echo (int) $zv_rcount; ?>)</span><?php endif; ?></h2><?php echo zv_icon('down', 20); // phpcs:ignore ?></summary>
                    <div class="zv-acc__body">
                        <?php if ($zv_reviews) : ?>
                            <ul class="zv-reviews__list">
                                <?php foreach ($zv_reviews as $rv) :
                                    $stars = (int) get_comment_meta((int) $rv->comment_ID, 'rating', true); ?>
                                    <li>
                                        <div class="zv-reviews__head"><strong><?php echo esc_html(wp_trim_words($rv->comment_author, 1, "")); ?></strong><span class="zv-stars" style="--r:<?php echo $stars; ?>" aria-label="<?php echo esc_attr(sprintf(zv_t('%d من 5', '%d of 5'), $stars)); ?>"></span><span class="zv-reviews__badge"><?php zv_e('اشترى المنتج', 'Verified buyer'); ?></span></div>
                                        <p><?php echo esc_html(wp_strip_all_tags($rv->comment_content)); ?></p>
                                    </li>
                                <?php endforeach; ?>
                            </ul>
                        <?php else : ?>
                            <p class="zv-reviews__empty"><?php zv_e('ما فيه تقييمات بعد. التقييم متاح لمن اشترى المنتج.', 'No reviews yet. Reviews come from customers who bought it.'); ?></p>
                        <?php endif; ?>

                        <?php if ($zv_bought && !$zv_mine && comments_open($id)) : ?>
                            <form class="zv-reviews__form" method="post" action="<?php echo esc_url(site_url('/wp-comments-post.php')); ?>">
                                <strong><?php zv_e('جرّبته؟ قيّمه لغيرك', 'Tried it? Rate it for others'); ?></strong>
                                <fieldset class="zv-rate" aria-label="<?php echo esc_attr(zv_t('التقييم', 'Rating')); ?>">
                                    <?php for ($s = 5; $s >= 1; $s--) : ?>
                                        <input type="radio" id="zv-rate-<?php echo $s; ?>" name="rating" value="<?php echo $s; ?>" required><label for="zv-rate-<?php echo $s; ?>" title="<?php echo $s; ?>">★</label>
                                    <?php endfor; ?>
                                </fieldset>
                                <textarea name="comment" rows="3" maxlength="1000" required placeholder="<?php echo esc_attr(zv_t('وش عجبك؟ وكيف تقبّله أليفك؟', 'What did you like? How did your pet take to it?')); ?>"></textarea>
                                <input type="hidden" name="comment_post_ID" value="<?php echo (int) $id; ?>">
                                <input type="hidden" name="comment_parent" value="0">
                                <?php wp_comment_form_unfiltered_html_nonce(); ?>
                                <button type="submit" class="zv-btn zv-btn--primary"><?php zv_e('أرسل التقييم', 'Send review'); ?></button>
                            </form>
                        <?php elseif ($zv_mine) : ?>
                            <p class="zv-reviews__empty"><?php zv_e('شكراً، وصلنا تقييمك.', 'Thanks — we have your review.'); ?></p>
                        <?php elseif (!$zv_uid) : ?>
                            <p class="zv-reviews__empty"><a href="<?php echo esc_url(add_query_arg('redirect_to', rawurlencode(get_permalink($id) . '?review=1#reviews'), wc_get_page_permalink('myaccount'))); ?>"><?php zv_e('اشتريته؟ سجّل دخولك واكتب تقييمك', 'Bought it? Sign in to review'); ?></a></p>
                        <?php endif; ?>
                    </div>
                </details>
            </section>
        </div>

        <?php
        $fbt_ids = array_map(static fn($c) => (int) $c['id'], (array) ($pdp['fbt'] ?? []));
        $sub_ids = array_map(static fn($c) => (int) $c['id'], (array) ($pdp['substitutes'] ?? []));
        if (count($fbt_ids) >= 2) {
            echo zv_rail(zv_t('يُشترى معه عادةً', 'Frequently bought together'), array_slice($fbt_ids, 0, 10), ['sub' => zv_t('أكمل طلبك — يوصل معه في نفس الشحنة', 'Complete your order')]); // phpcs:ignore
        }
        if (count($sub_ids) >= 2) {
            echo '<div id="zv-subs"></div>' . zv_rail(zv_t('بدائل قد تعجبك', 'You may also like'), array_slice($sub_ids, 0, 10)); // phpcs:ignore
        } elseif ($cat && count($fbt_ids) < 2) {
            $more = array_values(array_diff(Zv_Catalog::listing(['category' => $cat, 'per_page' => 11])['ids'], [$id]));
            echo zv_rail(sprintf(zv_t('المزيد من %s', 'More from %s'), html_entity_decode($cat->name)), array_slice($more, 0, 10), ['more' => get_term_link($cat)]); // phpcs:ignore
        }
        ?>
    </div>

    <?php if ($instock) : ?>
        <div class="zv-stickybuy zv-only-m" data-zv-stickybuy hidden>
            <div class="zv-stickybuy__price"><span data-zv-sticky-label><?php echo esc_html($chosen['label'] ?? ''); ?></span><?php echo zv_money($price); // phpcs:ignore ?></div>
            <button type="button" class="zv-btn zv-btn--primary" data-zv-sticky-add><?php echo zv_icon('bag', 18); // phpcs:ignore ?><?php zv_e('أضف للسلة', 'Add to cart'); ?></button>
        </div>
    <?php endif; ?>
    <?php
    do_action('woocommerce_after_single_product');
endwhile;

get_footer();
