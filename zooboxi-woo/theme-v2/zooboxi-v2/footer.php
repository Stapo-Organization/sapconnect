<?php
defined('ABSPATH') || exit;
$zv_menu    = Zv_Catalog::menu();
$zv_scope   = Zv_Scope::get();
$zv_account = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('myaccount') : home_url('/my-account/');
$zv_orders  = function_exists('wc_get_account_endpoint_url') ? wc_get_account_endpoint_url('orders') : $zv_account;
$zv_fav     = function_exists('wc_get_account_endpoint_url') ? wc_get_account_endpoint_url('wishlist') : $zv_account;
$zv_bundles = get_term_by('slug', 'zb-bundles', 'product_cat');
$zv_brands_page = get_page_by_path('brands');
$zv_policy  = static function (string $slug) {
    $p = get_page_by_path($slug);
    return $p ? get_permalink($p) : '';
};
?>
</main>

<footer class="zv-footer">
    <span class="zv-footer__peek" aria-hidden="true" data-zv-peek><img src="<?php echo esc_url(zv_img('peek-cat.webp')); ?>" alt="" width="180" height="154" loading="lazy"></span>
    <div class="zv-wrap">
        <ul class="zv-trust">
            <li><?php echo zv_bolt(22); // phpcs:ignore ?><span><strong><?php zv_e('إكسبريس خلال ساعتين', 'Express in 2 hours'); ?></strong><?php zv_e('داخل الرياض، طوال ساعات العمل', 'Inside Riyadh, during opening hours'); ?></span></li>
            <li><?php echo zv_icon('shield', 22); // phpcs:ignore ?><span><strong><?php zv_e('منتجات أصلية 100٪', '100% genuine'); ?></strong><?php zv_e('مستوردة مباشرة من المصنّع', 'Imported straight from the maker'); ?></span></li>
            <li><?php echo zv_icon('return', 22); // phpcs:ignore ?><span><strong><?php zv_e('إرجاع خلال 14 يوماً', '14-day returns'); ?></strong><?php zv_e('حسب سياسة الاستبدال والإرجاع', 'Under our returns policy'); ?></span></li>
            <li><?php echo zv_icon('card', 22); // phpcs:ignore ?><span><strong><?php zv_e('ادفع براحتك', 'Pay your way'); ?></strong><?php zv_e('مدى، Apple Pay، STC Pay والبطاقات', 'mada, Apple Pay, STC Pay, cards'); ?></span></li>
        </ul>

        <div class="zv-footer__cols">
            <div class="zv-footer__brand">
                <span class="zv-footer__logo"><?php echo zv_logo(64); // phpcs:ignore ?></span>
                <p><?php zv_e('كل ما يحتاجه أليفك في مكان واحد — أكل، رمل، مكافآت، عناية وألعاب من أكثر من 80 ماركة أصلية.', 'Everything your pet needs in one place.'); ?></p>
                <a class="zv-footer__mail" href="mailto:info@zooboxi.com"><?php echo zv_icon('mail', 18); // phpcs:ignore ?>info@zooboxi.com</a>
            </div>
            <div class="zv-footer__col">
                <h3><?php zv_e('تسوّق', 'Shop'); ?></h3>
                <ul>
                    <?php foreach ($zv_menu as $pet) : ?><li><a href="<?php echo esc_url($pet['url']); ?>"><?php echo esc_html($pet['name']); ?></a></li><?php endforeach; ?>
                    <?php if ($zv_bundles instanceof WP_Term) : ?><li><a href="<?php echo esc_url(get_term_link($zv_bundles)); ?>"><?php zv_e('البكجات', 'Bundles'); ?></a></li><?php endif; ?>
                    <?php if ($zv_brands_page) : ?><li><a href="<?php echo esc_url(get_permalink($zv_brands_page)); ?>"><?php zv_e('الماركات', 'Brands'); ?></a></li><?php endif; ?>
                </ul>
            </div>
            <div class="zv-footer__col">
                <h3><?php zv_e('نساعدك', 'Help'); ?></h3>
                <ul>
                    <?php foreach ([['shipping-policy', 'الشحن والتوصيل', 'Shipping'], ['return-policy', 'الاستبدال والإرجاع', 'Returns'], ['terms-conditions', 'الشروط والأحكام', 'Terms'], ['privacy-policy', 'سياسة الخصوصية', 'Privacy']] as [$slug, $ar, $en]) :
                        $u = $zv_policy($slug);
                        if ($u) : ?><li><a href="<?php echo esc_url($u); ?>"><?php zv_e($ar, $en); ?></a></li><?php endif;
                    endforeach; ?>
                    <li><a href="<?php echo esc_url($zv_orders); ?>"><?php zv_e('تتبّع طلبك', 'Track your order'); ?></a></li>
                </ul>
            </div>
            <div class="zv-footer__col">
                <h3><?php zv_e('حسابك', 'Account'); ?></h3>
                <ul>
                    <li><a href="<?php echo esc_url($zv_account); ?>"><?php echo is_user_logged_in() ? esc_html(zv_t('حسابي', 'My account')) : esc_html(zv_t('تسجيل الدخول', 'Sign in')); ?></a></li>
                    <li><a href="<?php echo esc_url($zv_orders); ?>"><?php zv_e('طلباتي', 'My orders'); ?></a></li>
                    <li><a href="<?php echo esc_url($zv_fav); ?>"><?php zv_e('المفضلة', 'Wishlist'); ?></a></li>
                </ul>
            </div>
        </div>

        <div class="zv-footer__legal">
            <div class="zv-footer__ids">
                <span><?php zv_e('السجل التجاري', 'CR'); ?> <bdi>7009370755</bdi></span>
                <span><?php zv_e('الرقم الضريبي', 'VAT'); ?> <bdi>310160668400003</bdi></span>
                <span><?php zv_e('منصة الأعمال', 'Business ID'); ?> <bdi>7012580143</bdi></span>
            </div>
            <div class="zv-footer__pay"><?php echo zv_pay_marks(); // phpcs:ignore ?></div>
            <p class="zv-footer__copy">© <?php echo esc_html(gmdate('Y')); ?> <?php zv_e('زوبوكسي · جميع الحقوق محفوظة', 'Zooboxi · All rights reserved'); ?></p>
        </div>
    </div>
</footer>

<nav class="zv-tabbar zv-only-m" aria-label="<?php echo esc_attr(zv_t('التنقل', 'Navigation')); ?>">
    <a href="<?php echo esc_url(home_url('/')); ?>"<?php echo is_front_page() ? ' aria-current="page"' : ''; ?>><?php echo zv_icon('home', 23); // phpcs:ignore ?><span><?php zv_e('الرئيسية', 'Home'); ?></span></a>
    <button type="button" data-zv-open="drawer"><?php echo zv_icon('grid', 23); // phpcs:ignore ?><span><?php zv_e('الأقسام', 'Shop'); ?></span></button>
    <button type="button" data-zv-focus-search><?php echo zv_icon('search', 23); // phpcs:ignore ?><span><?php zv_e('البحث', 'Search'); ?></span></button>
    <button type="button" data-zv-open="cart" class="zv-tabbar__cart"><?php echo zv_icon('bag', 23); // phpcs:ignore ?><span class="zv-cart-count<?php echo zv_cart_count() ? '' : ' is-zero'; ?>"><?php echo (int) zv_cart_count(); ?></span><span><?php zv_e('السلة', 'Cart'); ?></span></button>
    <a href="<?php echo esc_url($zv_account); ?>"<?php echo function_exists('is_account_page') && is_account_page() ? ' aria-current="page"' : ''; ?>><?php echo zv_icon('user', 23); // phpcs:ignore ?><span><?php zv_e('حسابي', 'Account'); ?></span></a>
</nav>

<?php /* ── Overlays ─────────────────────────────────────────── */ ?>
<div class="zv-scrim" data-zv-scrim hidden></div>

<aside class="zv-sheet zv-sheet--side" id="zv-cart" data-zv-panel="cart" aria-label="<?php echo esc_attr(zv_t('سلة التسوق', 'Shopping cart')); ?>" hidden>
    <div class="zv-sheet__head">
        <h2><?php zv_e('سلتك', 'Your cart'); ?> <span class="zv-cart-count<?php echo zv_cart_count() ? '' : ' is-zero'; ?>"><?php echo (int) zv_cart_count(); ?></span></h2>
        <button type="button" class="zv-iconbtn" data-zv-close aria-label="<?php echo esc_attr(zv_t('إغلاق', 'Close')); ?>"><?php echo zv_icon('close', 22); // phpcs:ignore ?></button>
    </div>
    <?php echo zv_minicart_body(); // phpcs:ignore ?>
</aside>

<aside class="zv-sheet zv-sheet--side zv-sheet--start" id="zv-drawer" data-zv-panel="drawer" aria-label="<?php echo esc_attr(zv_t('القائمة', 'Menu')); ?>" hidden>
    <div class="zv-sheet__head">
        <?php echo zv_logo(44); // phpcs:ignore ?>
        <button type="button" class="zv-iconbtn" data-zv-close aria-label="<?php echo esc_attr(zv_t('إغلاق', 'Close')); ?>"><?php echo zv_icon('close', 22); // phpcs:ignore ?></button>
    </div>
    <div class="zv-drawer">
        <button type="button" class="zv-drawer__loc" data-zv-open="location"><?php echo zv_icon('pin', 20); // phpcs:ignore ?><span><small><?php zv_e('التوصيل إلى', 'Deliver to'); ?></small><strong><?php echo esc_html($zv_scope['label'] !== '' ? $zv_scope['label'] : zv_t('حدّد موقعك', 'Set location')); ?></strong></span></button>
        <?php foreach ($zv_menu as $pet) : ?>
            <details class="zv-drawer__pet">
                <summary><img src="<?php echo esc_url(zv_species_art($pet['species'])); ?>" alt="" width="44" height="44" loading="lazy"><span><?php echo esc_html($pet['name']); ?></span><?php echo zv_icon('down', 18); // phpcs:ignore ?></summary>
                <ul>
                    <li><a href="<?php echo esc_url($pet['url']); ?>"><strong><?php echo esc_html(sprintf(zv_t('كل منتجات %s', 'All %s products'), $pet['title'])); ?></strong></a></li>
                    <?php foreach ($pet['depts'] as $d) : ?><li><a href="<?php echo esc_url($d['url']); ?>"><?php echo zv_icon($d['icon'], 18); // phpcs:ignore ?><?php echo esc_html($d['name']); ?></a></li><?php endforeach; ?>
                </ul>
            </details>
        <?php endforeach; ?>
        <ul class="zv-drawer__links">
            <?php if ($zv_bundles instanceof WP_Term) : ?><li><a href="<?php echo esc_url(get_term_link($zv_bundles)); ?>"><?php echo zv_icon('gift', 20); // phpcs:ignore ?><?php zv_e('البكجات', 'Bundles'); ?></a></li><?php endif; ?>
            <?php if ($zv_brands_page) : ?><li><a href="<?php echo esc_url(get_permalink($zv_brands_page)); ?>"><?php echo zv_icon('tag', 20); // phpcs:ignore ?><?php zv_e('الماركات', 'Brands'); ?></a></li><?php endif; ?>
            <li><a href="<?php echo esc_url($zv_orders); ?>"><?php echo zv_icon('box', 20); // phpcs:ignore ?><?php zv_e('طلباتي', 'My orders'); ?></a></li>
            <li><a href="<?php echo esc_url($zv_fav); ?>"><?php echo zv_icon('heart', 20); // phpcs:ignore ?><?php zv_e('المفضلة', 'Wishlist'); ?></a></li>
            <li><a href="<?php echo esc_url($zv_account); ?>"><?php echo zv_icon('user', 20); // phpcs:ignore ?><?php zv_e('حسابي', 'My account'); ?></a></li>
        </ul>
    </div>
</aside>

<div class="zv-sheet zv-sheet--modal" id="zv-location" data-zv-panel="location" role="dialog" aria-modal="true" aria-labelledby="zv-loc-title" hidden>
    <div class="zv-sheet__head">
        <h2 id="zv-loc-title"><?php zv_e('وين نوصّل طلبك؟', 'Where should we deliver?'); ?></h2>
        <button type="button" class="zv-iconbtn" data-zv-close aria-label="<?php echo esc_attr(zv_t('إغلاق', 'Close')); ?>"><?php echo zv_icon('close', 22); // phpcs:ignore ?></button>
    </div>
    <div class="zv-locsheet">
        <p class="zv-locsheet__hint"><?php zv_e('حرّك الخريطة حتى يكون الدبوس على بيتك — نعرض لك أسرع توصيل وما يتوفر عندك.', 'Move the map until the pin sits on your home.'); ?></p>
        <div class="zv-locsheet__map" data-zv-map>
            <div class="zv-locsheet__canvas" data-zv-map-canvas></div>
            <span class="zv-locsheet__pin" aria-hidden="true"><?php echo zv_icon('pin', 40); // phpcs:ignore ?></span>
            <button type="button" class="zv-locsheet__gps" data-zv-gps><?php echo zv_icon('locate', 18); // phpcs:ignore ?><?php zv_e('موقعي الحالي', 'Use my location'); ?></button>
        </div>
        <p class="zv-locsheet__addr" data-zv-addr aria-live="polite"></p>
        <p class="zv-locsheet__status" data-zv-loc-status aria-live="polite"></p>
        <button type="button" class="zv-btn zv-btn--primary zv-btn--block" data-zv-loc-confirm disabled><?php zv_e('تأكيد الموقع', 'Confirm location'); ?></button>
    </div>
</div>

<div class="zv-toasts" data-zv-toasts aria-live="polite"></div>
<script id="zv-cart-map" type="application/json"><?php echo wp_json_encode((object) zv_cart_map()); ?></script>

<?php wp_footer(); ?>
</body>
</html>
