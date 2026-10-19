<?php
defined('ABSPATH') || exit;
$zv_scope   = Zv_Scope::get();
$zv_promise = Zv_Scope::promise();
$zv_menu    = Zv_Catalog::menu();
$zv_count   = zv_cart_count();
$zv_account = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('myaccount') : home_url('/my-account/');
$zv_fav     = function_exists('wc_get_account_endpoint_url') ? wc_get_account_endpoint_url('wishlist') : $zv_account;
// The threshold every basket can count on. Express's lower one is promised only once the
// basket IS an إكسبريس basket — a زوبكسي basket is charged until the standard line.
$zv_free    = Zv_Scope::free_min_standard();
if ($zv_scope['located'] && class_exists('Zooboxi_Cart_Shelf') && class_exists('Zooboxi_Delivery_Engine')
    && Zooboxi_Cart_Shelf::current() === Zooboxi_Cart_Shelf::EXPRESS && Zooboxi_Delivery_Engine::express_free_min() > 0) {
    $zv_free = Zooboxi_Delivery_Engine::express_free_min();
}
$zv_free_shown = zv_free_display($zv_free);
$zv_bundles = get_term_by('slug', 'zb-bundles', 'product_cat');
$zv_brands_page = get_page_by_path('brands');
$zv_brands  = $zv_brands_page ? get_permalink($zv_brands_page) : '';
$zv_shop    = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/shop/');
?><!doctype html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo('charset'); ?>">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<?php wp_head(); ?>
</head>
<body <?php body_class('zv'); ?>>
<?php wp_body_open(); ?>
<a class="zv-skip" href="#zv-main"><?php zv_e('تخطَّ إلى المحتوى', 'Skip to content'); ?></a>

<div class="zv-promise zv-promise--<?php echo esc_attr($zv_promise['tone']); ?>">
    <div class="zv-wrap zv-promise__row">
        <span class="zv-promise__main">
            <?php echo $zv_promise['tone'] === 'express' ? zv_bolt(15) : zv_icon($zv_promise['tone'] === 'ask' ? 'pin' : 'truck', 16); // phpcs:ignore ?>
            <span><?php echo esc_html($zv_promise['text']); ?></span>
        </span>
        <?php if ($zv_promise['tone'] === 'ask') : ?>
            <button type="button" class="zv-promise__btn" data-zv-open="location"><?php zv_e('حدّد موقعك', 'Set location'); ?></button>
        <?php elseif ($zv_free > 0) : ?>
            <span class="zv-promise__free"><?php echo wp_kses_post(sprintf(zv_t('التوصيل مجاني فوق %s', 'Free delivery over %s'), zv_money(round($zv_free_shown, 2)))); ?></span>
        <?php endif; ?>
    </div>
</div>

<header class="zv-header" data-zv-header>
    <div class="zv-wrap zv-header__row">
        <button type="button" class="zv-iconbtn zv-only-m" data-zv-open="drawer" aria-label="<?php echo esc_attr(zv_t('القائمة', 'Menu')); ?>"><?php echo zv_icon('menu', 24); // phpcs:ignore ?></button>

        <a class="zv-header__logo" href="<?php echo esc_url(home_url('/')); ?>" aria-label="<?php echo esc_attr(zv_t('زوبوكسي — الرئيسية', 'Zooboxi — home')); ?>"><?php echo zv_logo(58); // phpcs:ignore ?></a>

        <form class="zv-search" role="search" method="get" action="<?php echo esc_url(home_url('/')); ?>" data-zv-search>
            <label class="zv-search__field">
                <span class="zv-sr"><?php zv_e('ابحث في المتجر', 'Search the store'); ?></span>
                <?php echo zv_icon('search', 20); // phpcs:ignore ?>
                <input type="search" name="s" value="<?php echo esc_attr(get_search_query()); ?>" placeholder="<?php echo esc_attr(zv_t('وش يحتاج أليفك اليوم؟ ابحث بالاسم أو الماركة أو الباركود', 'What does your pet need today?')); ?>" autocomplete="off" enterkeyhint="search" data-zv-q>
                <input type="hidden" name="post_type" value="product">
            </label>
            <div class="zv-suggest" data-zv-suggest hidden></div>
        </form>

        <div class="zv-header__actions">
            <button type="button" class="zv-loc" data-zv-open="location">
                <?php echo zv_icon('pin', 20); // phpcs:ignore ?>
                <span class="zv-loc__txt">
                    <small><?php zv_e('التوصيل إلى', 'Deliver to'); ?></small>
                    <strong><?php echo esc_html($zv_scope['label'] !== '' ? $zv_scope['label'] : zv_t('حدّد موقعك', 'Set location')); ?></strong>
                </span>
            </button>
            <a class="zv-iconbtn zv-only-d" href="<?php echo esc_url($zv_account); ?>" aria-label="<?php echo esc_attr(zv_t('حسابي', 'My account')); ?>"><?php echo zv_icon('user', 23); // phpcs:ignore ?></a>
            <a class="zv-iconbtn zv-only-d" href="<?php echo esc_url($zv_fav); ?>" aria-label="<?php echo esc_attr(zv_t('المفضلة', 'Wishlist')); ?>"><?php echo zv_icon('heart', 23); // phpcs:ignore ?></a>
            <button type="button" class="zv-cartbtn" data-zv-open="cart" aria-label="<?php echo esc_attr(zv_t('السلة', 'Cart')); ?>">
                <?php echo zv_icon('bag', 22); // phpcs:ignore ?>
                <span class="zv-cart-count<?php echo $zv_count ? '' : ' is-zero'; ?>"><?php echo (int) $zv_count; ?></span>
                <span class="zv-cart-total"><?php echo $zv_count ? zv_money(zv_cart_total()) : esc_html(zv_t('السلة', 'Cart')); // phpcs:ignore ?></span>
            </button>
        </div>
    </div>

    <nav class="zv-nav zv-only-d" aria-label="<?php echo esc_attr(zv_t('الأقسام', 'Departments')); ?>">
        <ul class="zv-wrap zv-nav__list">
            <?php foreach ($zv_menu as $pet) :
                $sp = $pet['species'];
                $tint = zv_species_tint($sp); ?>
                <li class="zv-nav__item has-mega" data-zv-mega>
                    <a class="zv-nav__link" href="<?php echo esc_url($pet['url']); ?>"><?php echo esc_html($pet['name']); ?><?php echo zv_icon('down', 14); // phpcs:ignore ?></a>
                    <div class="zv-mega" role="region" aria-label="<?php echo esc_attr($pet['name']); ?>">
                        <div class="zv-wrap zv-mega__inner">
                            <ul class="zv-mega__depts">
                                <?php foreach ($pet['depts'] as $i => $d) : ?>
                                    <li><a class="zv-mega__dept<?php echo $i === 0 ? ' is-on' : ''; ?>" href="<?php echo esc_url($d['url']); ?>" data-zv-dept="<?php echo esc_attr($sp . '-' . $i); ?>">
                                        <span class="zv-mega__ic zv-tint--<?php echo esc_attr($tint); ?>"><?php echo zv_icon($d['icon'], 20); // phpcs:ignore ?></span>
                                        <span class="zv-mega__dname"><?php echo esc_html($d['name']); ?></span>
                                        <?php echo zv_icon('left', 16, 'zv-mega__chev'); // phpcs:ignore ?>
                                    </a></li>
                                <?php endforeach; ?>
                                <li class="zv-mega__all"><a class="zv-more" href="<?php echo esc_url($pet['url']); ?>"><?php echo esc_html(sprintf(zv_t('كل منتجات %s', 'All %s products'), $pet['title'])); ?><?php echo zv_icon('more', 16); // phpcs:ignore ?></a></li>
                            </ul>
                            <div class="zv-mega__panels">
                                <?php foreach ($pet['depts'] as $i => $d) : ?>
                                    <section class="zv-mega__panel" data-zv-mpanel="<?php echo esc_attr($sp . '-' . $i); ?>"<?php echo $i ? ' hidden' : ''; ?>>
                                        <header class="zv-mega__phead">
                                            <a class="zv-mega__ptitle" href="<?php echo esc_url($d['url']); ?>"><?php echo esc_html($d['name']); ?><?php if ($d['for'] !== '') : ?> <small><?php echo esc_html($d['for']); ?></small><?php endif; ?></a>
                                            <a class="zv-more" href="<?php echo esc_url($d['url']); ?>"><?php echo esc_html(sprintf(zv_t('عرض الكل (%s)', 'See all (%s)'), number_format_i18n($d['count']))); ?><?php echo zv_icon('more', 16); // phpcs:ignore ?></a>
                                        </header>
                                        <?php foreach ($d['groups'] as $g) :
                                            if (!$g['tiles']) { continue; } ?>
                                            <?php if ($g['label'] !== '') : ?><h3 class="zv-mega__glabel"><?php echo esc_html($g['label']); ?></h3><?php endif; ?>
                                            <ul class="zv-mega__tiles">
                                                <?php foreach ($g['tiles'] as $t) : ?>
                                                    <li><a class="zv-mega__tile" href="<?php echo esc_url($t['url']); ?>">
                                                        <span class="zv-mega__timg"><?php if ($t['img']) : ?><img data-src="<?php echo esc_url($t['img']); ?>" alt="" width="52" height="52" decoding="async"><?php else : echo zv_icon($d['icon'], 22); endif; // phpcs:ignore ?></span>
                                                        <span class="zv-mega__tname"><?php echo esc_html($t['name']); ?></span>
                                                        <small><?php echo esc_html(zv_count((int) $t['count'], zv_t('منتج واحد', '1 product'), zv_t('منتجان', '2 products'), zv_t('منتجات', 'products'), zv_t('منتجاً', 'products'))); ?></small>
                                                    </a></li>
                                                <?php endforeach; ?>
                                            </ul>
                                        <?php endforeach; ?>
                                        <?php if ($d['top']) : ?>
                                            <h3 class="zv-mega__glabel"><?php zv_e('الأكثر طلباً', 'Best sellers'); ?></h3>
                                            <ul class="zv-mega__tiles zv-mega__tiles--products">
                                                <?php foreach ($d['top'] as $t) : ?>
                                                    <li><a class="zv-mega__tile" href="<?php echo esc_url($t['url']); ?>">
                                                        <span class="zv-mega__timg"><?php if ($t['img']) : ?><img data-src="<?php echo esc_url($t['img']); ?>" alt="" width="52" height="52" decoding="async"><?php endif; ?></span>
                                                        <span class="zv-mega__tname"><?php echo esc_html($t['name']); ?></span>
                                                    </a></li>
                                                <?php endforeach; ?>
                                            </ul>
                                        <?php endif; ?>
                                    </section>
                                <?php endforeach; ?>
                            </div>
                            <aside class="zv-mega__aside">
                                <?php if ($pet['brands']) : ?>
                                    <h3 class="zv-mega__glabel"><?php echo esc_html(sprintf(zv_t('ماركات %s', 'Brands %s'), zv_for_pet($sp, $pet['name']))); ?></h3>
                                    <ul class="zv-mega__brands">
                                        <?php foreach ($pet['brands'] as $b) : ?>
                                            <li><a href="<?php echo esc_url($b['url']); ?>" title="<?php echo esc_attr($b['name']); ?>"><img data-src="<?php echo esc_url($b['logo']); ?>" alt="<?php echo esc_attr($b['name']); ?>" width="88" height="36" decoding="async"></a></li>
                                        <?php endforeach; ?>
                                    </ul>
                                <?php endif; ?>
                                <a class="zv-mega__promo zv-tint--<?php echo esc_attr($tint); ?>" href="<?php echo esc_url($pet['url']); ?>">
                                    <span class="zv-mega__promotxt">
                                        <strong><?php echo esc_html(sprintf(zv_t('كل منتجات %s', 'Everything for %s'), $pet['title'])); ?></strong>
                                        <small><?php echo esc_html(zv_count((int) $pet['count'], zv_t('منتج واحد', '1 product'), zv_t('منتجان', '2 products'), zv_t('منتجات', 'products'), zv_t('منتجاً', 'products'))); ?></small>
                                        <span class="zv-more"><?php zv_e('تسوّق الآن', 'Shop now'); ?><?php echo zv_icon('more', 16); // phpcs:ignore ?></span>
                                    </span>
                                    <img data-src="<?php echo esc_url(zv_species_art($sp)); ?>" alt="" width="96" height="96" decoding="async">
                                </a>
                            </aside>
                        </div>
                    </div>
                </li>
            <?php endforeach; ?>
            <?php if ($zv_bundles instanceof WP_Term) : ?>
                <li class="zv-nav__item"><a class="zv-nav__link zv-nav__link--hl" href="<?php echo esc_url(get_term_link($zv_bundles)); ?>"><?php echo zv_icon('gift', 17); // phpcs:ignore ?><?php zv_e('البكجات', 'Bundles'); ?></a></li>
            <?php endif; ?>
            <li class="zv-nav__item"><a class="zv-nav__link" href="<?php echo esc_url($zv_brands ?: $zv_shop); ?>"><?php zv_e('الماركات', 'Brands'); ?></a></li>
            <li class="zv-nav__item"><a class="zv-nav__link" href="<?php echo esc_url($zv_shop); ?>"><?php zv_e('كل المنتجات', 'All products'); ?></a></li>
        </ul>
    </nav>
</header>

<main id="zv-main" class="zv-main">
