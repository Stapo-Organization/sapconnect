<?php
/**
 * Single order — journey first, paperwork second.
 *
 * The standard details table still renders via woocommerce_view_order so any
 * plugin hooked there (payment, fulfilment) keeps working; we only add the
 * narrative around it.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

$notes   = $order->get_customer_order_notes();
$line    = zooboxi_order_timeline($order);
$status  = $order->get_status();
$created = $order->get_date_created();
$dtype   = (string) $order->get_meta('_zooboxi_delivery_type');
[$dic, $dlabel, $dnote] = zooboxi_delivery_type_ar($dtype);
$count   = $order->get_item_count() - $order->get_item_count_refunded();
?>

<section class="zbx-vieworder">

    <header class="zbx-vo-head">
        <div>
            <span class="zbx-vo-head__cap">طلب رقم</span>
            <strong class="zbx-vo-head__no">#<?php echo esc_html($order->get_order_number()); ?></strong>
            <?php if ($created) : ?>
                <span class="zbx-vo-head__date"><?php echo esc_html(zooboxi_date_ar_ts($created->getTimestamp())); ?></span>
            <?php endif; ?>
        </div>
        <span class="zbx-pill zbx-pill--<?php echo esc_attr(zooboxi_status_tone($status)); ?> zbx-pill--lg">
            <?php echo esc_html(zooboxi_status_ar($status)); ?>
        </span>
    </header>

    <?php if (!$line['dead']) : ?>
        <ol class="zbx-track zbx-track--wide">
            <?php foreach ($line['steps'] as $s) : ?>
                <li class="zbx-track__step is-<?php echo esc_attr($s['state']); ?>">
                    <span class="zbx-track__ic" aria-hidden="true"><?php echo esc_html($s['icon']); ?></span>
                    <span class="zbx-track__tx">
                        <strong><?php echo esc_html($s['title']); ?></strong>
                        <em><?php echo esc_html($s['note']); ?></em>
                    </span>
                </li>
            <?php endforeach; ?>
        </ol>
    <?php else : ?>
        <p class="zbx-vo-dead"><span aria-hidden="true">⚠️</span> هذا الطلب <?php echo esc_html($line['label']); ?>. لأي استفسار تواصل معنا وسنساعدك.</p>
    <?php endif; ?>

    <div class="zbx-vo-facts">
        <?php if ($dtype) : ?>
            <div class="zbx-vo-fact">
                <span class="zbx-vo-fact__ic" aria-hidden="true"><?php echo esc_html($dic); ?></span>
                <span><strong><?php echo esc_html($dlabel); ?></strong><em><?php echo esc_html($dnote); ?></em></span>
            </div>
        <?php endif; ?>

        <div class="zbx-vo-fact">
            <span class="zbx-vo-fact__ic" aria-hidden="true">📦</span>
            <span><strong><?php echo esc_html(zooboxi_count_ar((int) $count, 'صنف واحد', 'صنفان', 'أصناف', 'صنفاً')); ?></strong><em>في هذا الطلب</em></span>
        </div>

        <div class="zbx-vo-fact">
            <span class="zbx-vo-fact__ic" aria-hidden="true">💳</span>
            <span><strong><?php echo esc_html($order->get_payment_method_title() ?: 'غير محدد'); ?></strong><em>طريقة الدفع</em></span>
        </div>

        <?php
        $addr = $order->get_formatted_billing_address();
        if ($addr) : ?>
            <div class="zbx-vo-fact zbx-vo-fact--addr">
                <span class="zbx-vo-fact__ic" aria-hidden="true">📍</span>
                <span><strong>عنوان التوصيل</strong><em><?php echo wp_kses_post($addr); ?></em></span>
            </div>
        <?php endif; ?>
    </div>

    <?php if (in_array($status, ['completed', 'zb-ready'], true)) : ?>
        <button type="button" class="zbx-btn zbx-btn--solid zbx-obtn--reorder zbx-vo-reorder"
                data-order="<?php echo esc_attr($order->get_id()); ?>">
            <span aria-hidden="true">🔁</span> أعد طلب نفس الأصناف
        </button>
    <?php endif; ?>

    <?php if ($notes) : ?>
        <section class="zbx-vo-notes">
            <h2><span aria-hidden="true">💬</span> تحديثات الطلب</h2>
            <ol>
                <?php foreach ($notes as $note) : ?>
                    <li>
                        <span class="zbx-vo-notes__when"><?php echo esc_html(zooboxi_date_ar_ts(strtotime($note->comment_date))); ?></span>
                        <div class="zbx-vo-notes__tx"><?php echo wp_kses_post(wpautop(wptexturize($note->comment_content))); ?></div>
                    </li>
                <?php endforeach; ?>
            </ol>
        </section>
    <?php endif; ?>

    <div class="zbx-vo-details">
        <?php do_action('woocommerce_view_order', $order_id); ?>
    </div>

    <a class="zbx-vo-back" href="<?php echo esc_url(wc_get_account_endpoint_url('orders')); ?>">→ رجوع لكل الطلبات</a>

</section>
