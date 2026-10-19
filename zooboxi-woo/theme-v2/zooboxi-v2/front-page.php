<?php
/**
 * Home — «البيت»: the teal stage with the characters, the four pets, what is
 * selling for each pet, bundles, new arrivals and brands. Every rail is scoped
 * to what reaches this customer, so nothing on the home page is unbuyable.
 */
defined('ABSPATH') || exit;
get_header();

$s        = Zv_Scope::get();
$menu     = Zv_Catalog::menu();
$express  = $s['express_zone'];
$products = Zv_Catalog::product_count();
$brands_n = Zv_Catalog::brand_count();
$shop     = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/shop/');
$bundles_term = get_term_by('slug', 'zb-bundles', 'product_cat');
$brands_page  = get_page_by_path('brands');

/** Rendered rails are the same for every guest at the same reachable warehouses. */
$cache = static function (string $key, callable $render): string {
    if (is_user_logged_in()) {
        return $render();
    }
    $k = 'zv_home_' . md5($key . '|' . Zv_Scope::key() . '|' . zv_lang() . '|' . (class_exists('Zooboxi_Fulfillment') ? Zooboxi_Fulfillment::standard_day_label() : ''));
    $html = get_transient($k);
    if (!is_string($html)) {
        $html = $render();
        set_transient($k, $html, 10 * MINUTE_IN_SECONDS);
    }
    return $html;
};
?>

<section class="zv-wrap zv-hero">
    <div class="zv-hero__stage">
        <div class="zv-hero__copy">
            <?php if ($s['express_open']) : ?>
                <span class="zv-pill zv-pill--light"><?php echo zv_bolt(14); // phpcs:ignore ?><?php zv_e('إكسبريس متاح الآن', 'Express is on now'); ?></span>
            <?php elseif ($s['located']) : ?>
                <span class="zv-pill zv-pill--light"><?php echo zv_icon('truck', 15); // phpcs:ignore ?><?php echo esc_html(Zv_Scope::promise()['text']); ?></span>
            <?php endif; ?>
            <h1 class="zv-hero__title">
                <?php if ($express || !$s['located']) : ?>
                    <?php zv_e('كل ما يحتاجه أليفك، يوصلك خلال ساعتين', 'Everything your pet needs, in two hours'); ?>
                <?php else : ?>
                    <?php zv_e('كل ما يحتاجه أليفك، لين باب البيت', 'Everything your pet needs, to your door'); ?>
                <?php endif; ?>
            </h1>
            <p class="zv-hero__lead">
                <?php if ($express || !$s['located']) : ?>
                    <?php zv_e('أكل، رمل، مكافآت وعناية من ماركات أصلية — وإكسبريس داخل الرياض خلال ساعتين.', 'Food, litter, treats and care from genuine brands — express in Riyadh within two hours.'); ?>
                <?php else : ?>
                    <?php zv_e('أكل، رمل، مكافآت وعناية من ماركات أصلية — نشحن لكل مدن المملكة.', 'Food, litter, treats and care from genuine brands — shipped across Saudi Arabia.'); ?>
                <?php endif; ?>
            </p>
            <div class="zv-hero__ctas">
                <?php if (!empty($menu[0])) : ?><a class="zv-btn zv-btn--cream" href="<?php echo esc_url($menu[0]['url']); ?>" data-zv-cue="<?php echo esc_attr($menu[0]['species']); ?>"><?php echo esc_html(zv_t('تسوّق ', 'Shop ') . zv_for_pet($menu[0]['species'], $menu[0]['name'])); ?></a><?php endif; ?>
                <?php if (!empty($menu[1])) : ?><a class="zv-btn zv-btn--outline-light" href="<?php echo esc_url($menu[1]['url']); ?>" data-zv-cue="<?php echo esc_attr($menu[1]['species']); ?>"><?php echo esc_html(zv_t('تسوّق ', 'Shop ') . zv_for_pet($menu[1]['species'], $menu[1]['name'])); ?></a><?php endif; ?>
            </div>
            <ul class="zv-hero__facts">
                <li><strong data-zv-count="<?php echo (int) (floor($products / 100) * 100); ?>" data-suffix="+"><?php echo esc_html(number_format_i18n(floor($products / 100) * 100)); ?>+</strong><span><?php zv_e('منتج', 'products'); ?></span></li>
                <li><strong data-zv-count="<?php echo (int) $brands_n; ?>"><?php echo esc_html(number_format_i18n($brands_n)); ?></strong><span><?php zv_e('ماركة', 'brands'); ?></span></li>
                <li><strong data-zv-count="100" data-suffix="٪">100٪</strong><span><?php zv_e('أصلي', 'genuine'); ?></span></li>
            </ul>
        </div>
        <div class="zv-hero__art" aria-hidden="true" data-zv-stage>
            <span class="zv-hero__floor"></span>
            <img class="zv-hero__fx zv-hero__fx--1" src="<?php echo esc_url(zv_img('fx-star.webp')); ?>" alt="" width="72" height="68">
            <img class="zv-hero__fx zv-hero__fx--2" src="<?php echo esc_url(zv_img('fx-heart.webp')); ?>" alt="" width="72" height="64">
            <img class="zv-hero__fx zv-hero__fx--3" src="<?php echo esc_url(zv_img('fx-star.webp')); ?>" alt="" width="72" height="68">
            <?php
            echo zv_char('hero-dog-wave.webp', [ // phpcs:ignore
                'wow'       => ['hero-dog-wow.webp', 0.86],
                'jump'      => ['hero-dog-jump.webp', 0.76],
                'celebrate' => ['hero-dog-celebrate.webp', 0.80],
            ], ['class' => 'zv-hero__dog', 'w' => 600, 'h' => 553, 'eager' => true, 'who' => 'dog']);
            echo zv_char('hero-cat-wave.webp', [ // phpcs:ignore
                'wow'       => ['hero-cat-wow.webp', 0.95],
                'jump'      => ['hero-cat-jump.webp', 0.78],
                'celebrate' => ['hero-cat-celebrate.webp', 0.80],
            ], ['class' => 'zv-hero__cat', 'w' => 600, 'h' => 579, 'eager' => true, 'who' => 'cat']);
            ?>
        </div>
    </div>
</section>

<section class="zv-wrap zv-section zv-pets" aria-labelledby="zv-pets-title">
    <h2 class="zv-h2 zv-center" id="zv-pets-title"><?php zv_e('لمين تتسوّق اليوم؟', 'Who are you shopping for?'); ?></h2>
    <div class="zv-pets__row">
        <?php foreach ($menu as $pet) : ?>
            <a class="zv-pet zv-pet--<?php echo esc_attr($pet['species']); ?>" href="<?php echo esc_url($pet['url']); ?>">
                <span class="zv-pet__disc zv-tint--<?php echo esc_attr(zv_species_tint($pet['species'])); ?>"><?php echo zv_pet_char($pet['species']); // phpcs:ignore ?></span>
                <span class="zv-pet__name"><?php echo esc_html($pet['name']); ?></span>
            </a>
        <?php endforeach; ?>
    </div>
</section>

<?php
echo $cache('top', static function () use ($menu) { // phpcs:ignore
    $panels = [];
    foreach ($menu as $pet) {
        $ids = Zv_Catalog::rail_species((int) $pet['id'], 14);
        $cards = array_slice(array_values(array_filter(Zv_Catalog::cards($ids), static fn($c) => ($c['stock_status'] ?? 'instock') === 'instock')), 0, 10);
        if (count($cards) >= 4) {
            $panels[] = ['pet' => $pet, 'cards' => $cards];
        }
    }
    if (!$panels) {
        return '';
    }
    ob_start(); ?>
    <section class="zv-wrap zv-section zv-rail zv-tabs" data-zv-tabs>
        <div class="zv-section__head">
            <div>
                <h2 class="zv-h2"><?php zv_e('الأكثر طلباً هالأسبوع', 'Most wanted this week'); ?></h2>
                <div class="zv-tabs__list" role="tablist">
                    <?php foreach ($panels as $i => $p) : ?>
                        <button type="button" role="tab" id="zv-tab-<?php echo esc_attr($p['pet']['species']); ?>" aria-controls="zv-panel-<?php echo esc_attr($p['pet']['species']); ?>" aria-selected="<?php echo $i === 0 ? 'true' : 'false'; ?>" class="zv-chipbtn"><?php echo esc_html($p['pet']['name']); ?></button>
                    <?php endforeach; ?>
                </div>
            </div>
        </div>
        <?php foreach ($panels as $i => $p) : ?>
            <div class="zv-rail__track" role="tabpanel" id="zv-panel-<?php echo esc_attr($p['pet']['species']); ?>" aria-labelledby="zv-tab-<?php echo esc_attr($p['pet']['species']); ?>"<?php echo $i ? ' hidden' : ''; ?>>
                <?php foreach ($p['cards'] as $j => $c) {
                    echo zv_card($c, ['hide_badges' => ['hot'], 'eager' => $i === 0 && $j < 4]); // phpcs:ignore
                } ?>
                <a class="zv-rail__end" href="<?php echo esc_url($p['pet']['url']); ?>"><img src="<?php echo esc_url(zv_species_art($p['pet']['species'])); ?>" alt="" width="120" height="120" loading="lazy"><span><?php echo esc_html(sprintf(zv_t('كل منتجات %s', 'All %s products'), $p['pet']['name'])); ?></span><?php echo zv_icon('more', 18); // phpcs:ignore ?></a>
            </div>
        <?php endforeach; ?>
    </section>
    <?php
    return (string) ob_get_clean();
});

if ($bundles_term instanceof WP_Term) {
    echo $cache('bundles', static function () use ($bundles_term) { // phpcs:ignore
        $cards = array_values(array_filter(Zv_Catalog::cards(Zv_Catalog::bundle_ids(8)), static fn($c) => ($c['stock_status'] ?? 'instock') === 'instock'));
        $cards = array_slice($cards, 0, 6);
        if (count($cards) < 2) {
            return '';
        }
        $best = 0;
        foreach ($cards as $c) {
            $best = max($best, (int) ($c['discount_pct'] ?? 0));
        }
        ob_start(); ?>
        <section class="zv-wrap zv-section">
            <div class="zv-band zv-band--peach">
                <div class="zv-band__copy">
                    <span class="zv-pill zv-pill--coral"><?php echo zv_icon('gift', 15); // phpcs:ignore ?><?php zv_e('البكجات', 'Bundles'); ?></span>
                    <h2 class="zv-band__title"><?php zv_e('وفّر مع البكجات', 'Save with bundles'); ?></h2>
                    <p><?php echo $best >= 5 ? esc_html(sprintf(zv_t('بكجات مختارة من نفس الماركة، بتوفير يصل إلى %d٪.', 'Curated same-brand bundles, saving up to %d%%.'), $best)) : esc_html(zv_t('بكجات مختارة من نفس الماركة، بتوفير حقيقي.', 'Curated same-brand bundles with real savings.')); ?></p>
                    <a class="zv-btn zv-btn--ink" href="<?php echo esc_url(get_term_link($bundles_term)); ?>"><?php zv_e('كل البكجات', 'All bundles'); ?></a>
                </div>
                <img class="zv-band__art" src="<?php echo esc_url(zv_img('cat-lie.webp')); ?>" alt="" width="360" height="240" loading="lazy" data-zv-live>
            </div>
            <div class="zv-rail__track zv-rail__track--bundles">
                <?php foreach ($cards as $c) {
                    echo zv_card($c); // phpcs:ignore
                } ?>
            </div>
        </section>
        <?php
        return (string) ob_get_clean();
    });
}

echo $cache('new', static function () use ($shop) { // phpcs:ignore
    return zv_rail(zv_t('وصل حديثاً', 'Just arrived'), Zv_Catalog::rail_new(10), ['class' => 'zv-wrap', 'more' => add_query_arg('orderby', 'date', $shop), 'hide_badges' => ['new']]);
});

$brands = Zv_Catalog::brands(12);
if ($brands) : ?>
    <section class="zv-wrap zv-section">
        <div class="zv-section__head">
            <h2 class="zv-h2"><?php zv_e('ماركات أليفك المفضّلة', 'Brands your pet loves'); ?></h2>
            <?php if ($brands_page) : ?><a class="zv-more" href="<?php echo esc_url(get_permalink($brands_page)); ?>"><?php echo esc_html(sprintf(zv_t('كل الماركات (%d)', 'All brands (%d)'), $brands_n)); ?><?php echo zv_icon('more', 16); // phpcs:ignore ?></a><?php endif; ?>
        </div>
        <div class="zv-brands">
            <?php foreach ($brands as $b) : ?>
                <a class="zv-brand" href="<?php echo esc_url($b['url']); ?>"><img src="<?php echo esc_url($b['logo']); ?>" alt="<?php echo esc_attr($b['name']); ?>" width="150" height="100" loading="lazy"></a>
            <?php endforeach; ?>
        </div>
    </section>
<?php endif; ?>

<?php get_footer();
