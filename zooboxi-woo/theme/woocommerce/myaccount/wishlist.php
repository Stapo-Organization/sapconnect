<?php
/**
 * "المفضلة" — the customer's saved products.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

$zbx_ids  = zooboxi_wishlist();
$zbx_rows = [];

foreach ($zbx_ids as $zbx_pid) {
    $zbx_p = wc_get_product($zbx_pid);
    if ($zbx_p && $zbx_p->is_visible()) {
        $zbx_rows[] = $zbx_p;
    }
}
?>

<section class="zbx-mine zbx-favs">

    <?php if ($zbx_rows) : ?>

        <header class="zbx-block__head zbx-mine__head">
            <h2><span aria-hidden="true">💚</span> المفضلة</h2>
            <p><?php echo esc_html(zooboxi_count_ar(count($zbx_rows), 'صنف واحد', 'صنفان', 'أصناف', 'صنفاً')); ?> محفوظة — أضفها للسلة وقت ما تبغى</p>
        </header>

        <ul class="zbx-mine__grid">
            <?php foreach ($zbx_rows as $zbx_p) :
                $zbx_pid  = $zbx_p->get_id();
                $zbx_buy  = $zbx_p->is_purchasable() && $zbx_p->is_in_stock();
                ?>
                <li class="product zbx-mine__item zbx-fav-card" data-fav-card="<?php echo esc_attr($zbx_pid); ?>">

                    <a class="zbx-mine__img" href="<?php echo esc_url($zbx_p->get_permalink()); ?>">
                        <?php echo wp_kses_post($zbx_p->get_image('woocommerce_thumbnail')); ?>
                    </a>
                    <?php echo zooboxi_fav_button($zbx_pid, 'card'); // phpcs:ignore WordPress.Security.EscapeOutput ?>

                    <a class="zbx-mine__name" href="<?php echo esc_url($zbx_p->get_permalink()); ?>"><?php echo esc_html($zbx_p->get_name()); ?></a>
                    <span class="zbx-mine__price"><?php echo wp_kses_post($zbx_p->get_price_html()); ?></span>

                    <?php if ($zbx_buy) : ?>
                        <a href="?add-to-cart=<?php echo esc_attr($zbx_pid); ?>"
                           data-quantity="1" data-product_id="<?php echo esc_attr($zbx_pid); ?>"
                           class="button add_to_cart_button ajax_add_to_cart zbx-mine__add"
                           rel="nofollow">أضف للسلة</a>
                    <?php else : ?>
                        <span class="zbx-mine__out">غير متوفر حالياً</span>
                    <?php endif; ?>

                </li>
            <?php endforeach; ?>
        </ul>

    <?php else : ?>

        <div class="zbx-empty">
            <span class="zbx-empty__ic" aria-hidden="true">💚</span>
            <h2>قائمة المفضلة فاضية</h2>
            <p>اضغط على القلب ♡ على أي منتج يعجبك، وتلقاه محفوظ هنا في أي وقت ومن أي جهاز.</p>
            <a class="zbx-btn zbx-btn--solid" href="<?php echo esc_url(wc_get_page_permalink('shop')); ?>">تصفّح المتجر</a>
        </div>

    <?php endif; ?>

</section>
