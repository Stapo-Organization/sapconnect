<?php
/**
 * "مشترياتي" — everything this customer has ever bought, one tap from the cart.
 *
 * For a pet store this is the highest-value screen in the account: food and
 * litter are repeat purchases, and re-finding them through search is friction.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

$stats = zooboxi_account_stats(get_current_user_id());
$rows  = [];

foreach ($stats['products'] as $pid => $row) {
    $p = wc_get_product($pid);
    if (!$p) {
        continue;
    }
    $dates = $row['dates'] ?? [];
    rsort($dates);
    $rows[] = [
        'p'      => $p,
        'orders' => (int) $row['orders'],
        'qty'    => (int) $row['qty'],
        'last'   => $dates[0] ?? 0,
        'due'    => isset($stats['due_products'][$pid]),
        'buyable' => $p->is_purchasable() && $p->is_in_stock(),
    ];
}
?>

<section class="zbx-mine">

    <?php if ($rows) : ?>

        <header class="zbx-block__head zbx-mine__head">
            <h2><span aria-hidden="true">🛍️</span> كل ما اشتريته</h2>
            <p><?php echo esc_html(zooboxi_count_ar(count($rows), 'صنف واحد', 'صنفان', 'أصناف', 'صنفاً')); ?> — مرتّبة من الأكثر طلباً</p>
        </header>

        <ul class="zbx-mine__grid">
            <?php foreach ($rows as $r) :
                $p = $r['p'];
                ?>
                <li class="product zbx-mine__item <?php echo $r['due'] ? 'is-due' : ''; ?>">

                    <a class="zbx-mine__img" href="<?php echo esc_url($p->get_permalink()); ?>">
                        <?php echo wp_kses_post($p->get_image('woocommerce_thumbnail')); ?>
                        <?php if ($r['due']) : ?>
                            <span class="zbx-mine__due">🔁 وقت إعادة الطلب</span>
                        <?php endif; ?>
                    </a>

                    <a class="zbx-mine__name" href="<?php echo esc_url($p->get_permalink()); ?>"><?php echo esc_html($p->get_name()); ?></a>

                    <span class="zbx-mine__stats">
                        طلبته <?php echo esc_html(zooboxi_count_ar($r['orders'], 'مرة واحدة', 'مرتين', 'مرات', 'مرة')); ?>
                        <?php if ($r['last']) : ?>
                            · آخر مرة <?php echo esc_html(zooboxi_ago_ar((int) $r['last'])); ?>
                        <?php endif; ?>
                    </span>

                    <span class="zbx-mine__price"><?php echo wp_kses_post($p->get_price_html()); ?></span>

                    <?php if ($r['buyable']) : ?>
                        <a href="?add-to-cart=<?php echo esc_attr($p->get_id()); ?>"
                           data-quantity="1" data-product_id="<?php echo esc_attr($p->get_id()); ?>"
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
            <span class="zbx-empty__ic" aria-hidden="true">🛍️</span>
            <h2>لم تشترِ شيئاً بعد</h2>
            <p>بمجرد أول طلب، تلقى كل أصنافك هنا وتعيد طلبها بضغطة واحدة.</p>
            <a class="zbx-btn zbx-btn--solid" href="<?php echo esc_url(wc_get_page_permalink('shop')); ?>">تصفّح المتجر</a>
        </div>

    <?php endif; ?>

</section>
