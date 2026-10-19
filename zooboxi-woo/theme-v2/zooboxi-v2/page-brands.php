<?php
/** /brands/ — every brand, A–Z, with its logo; letters jump the list. */
defined('ABSPATH') || exit;
get_header();
$terms = taxonomy_exists('product_brand') ? get_terms(['taxonomy' => 'product_brand', 'hide_empty' => true, 'orderby' => 'name', 'order' => 'ASC']) : [];
$skip  = ['feline-go', 'felyn-go-en', 'whimzees-en'];
$groups = [];
foreach (is_array($terms) ? $terms : [] as $t) {
    if (in_array($t->slug, $skip, true)) {
        continue;
    }
    $name = html_entity_decode($t->name);
    $letter = strtoupper(mb_substr(remove_accents($name), 0, 1));
    $letter = preg_match('/[A-Z]/', $letter) ? $letter : '#';
    $logo_id = (int) get_term_meta($t->term_id, 'thumbnail_id', true);
    $groups[$letter][] = ['name' => $name, 'url' => get_term_link($t), 'logo' => $logo_id ? wp_get_attachment_image_url($logo_id, 'medium') : '', 'count' => (int) $t->count];
}
ksort($groups);
?>
<div class="zv-wrap">
    <?php echo zv_crumbs([[zv_t('الرئيسية', 'Home'), home_url('/')], [zv_t('الماركات', 'Brands'), null]]); // phpcs:ignore ?>
    <section class="zv-listhead zv-tint--mint">
        <div class="zv-listhead__copy">
            <h1 class="zv-listhead__title"><?php zv_e('كل الماركات', 'All brands'); ?></h1>
            <p class="zv-listhead__meta"><?php echo esc_html(sprintf(zv_t('%d ماركة أصلية لقطتك وكلبك وطيرك', '%d genuine brands'), array_sum(array_map('count', $groups)))); ?></p>
        </div>
        <img class="zv-listhead__art" src="<?php echo esc_url(zv_img('cat-present.webp')); ?>" alt="" width="160" height="240">
    </section>
    <nav class="zv-letters" aria-label="<?php echo esc_attr(zv_t('الحروف', 'Letters')); ?>">
        <?php foreach (array_keys($groups) as $l) : ?><a href="#zv-l-<?php echo esc_attr($l === '#' ? 'num' : $l); ?>"><?php echo esc_html($l); ?></a><?php endforeach; ?>
    </nav>
    <?php foreach ($groups as $l => $list) : ?>
        <section class="zv-brandgroup" id="zv-l-<?php echo esc_attr($l === '#' ? 'num' : $l); ?>">
            <h2 class="zv-brandgroup__letter"><?php echo esc_html($l); ?></h2>
            <div class="zv-brands zv-brands--all">
                <?php foreach ($list as $b) : ?>
                    <a class="zv-brand zv-brand--named" href="<?php echo esc_url($b['url']); ?>">
                        <?php if ($b['logo']) : ?><img src="<?php echo esc_url($b['logo']); ?>" alt="" width="150" height="100" loading="lazy"><?php else : ?><span class="zv-brand__word"><?php echo esc_html($b['name']); ?></span><?php endif; ?>
                        <span class="zv-brand__name"><?php echo esc_html($b['name']); ?> <small><?php echo (int) $b['count']; ?></small></span>
                    </a>
                <?php endforeach; ?>
            </div>
        </section>
    <?php endforeach; ?>
</div>
<?php get_footer();
