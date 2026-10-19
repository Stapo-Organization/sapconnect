<?php
/**
 * Addresses — as cards, with an obvious empty state.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

$customer_id = get_current_user_id();

if (!wc_ship_to_billing_address_only() && wc_shipping_enabled()) {
    $get_addresses = apply_filters('woocommerce_my_account_get_addresses', [
        'billing'  => 'عنوان التوصيل',
        'shipping' => 'عنوان الشحن',
    ], $customer_id);
} else {
    $get_addresses = apply_filters('woocommerce_my_account_get_addresses', [
        'billing' => 'عنوان التوصيل',
    ], $customer_id);
}
?>

<section class="zbx-addr">

    <header class="zbx-block__head">
        <h2><span aria-hidden="true">📍</span> عناويني</h2>
        <p>العنوان المحفوظ يُملأ تلقائياً عند إتمام أي طلب</p>
    </header>

    <div class="zbx-addr__grid">
        <?php foreach ($get_addresses as $name => $address_title) :
            $address = wc_get_account_formatted_address($name);
            ?>
            <article class="zbx-addr__card <?php echo $address ? 'is-set' : 'is-empty'; ?>">
                <header class="zbx-addr__top">
                    <h3><span aria-hidden="true"><?php echo $name === 'shipping' ? '🚚' : '🏠'; ?></span> <?php echo esc_html($address_title); ?></h3>
                    <?php if ($address) : ?>
                        <span class="zbx-addr__ok" aria-hidden="true">✓</span>
                    <?php endif; ?>
                </header>

                <div class="zbx-addr__body">
                    <?php if ($address) : ?>
                        <address><?php echo wp_kses_post($address); ?></address>
                    <?php else : ?>
                        <p class="zbx-addr__none">لم تضف هذا العنوان بعد — إضافته تختصر خطوات الطلب القادم.</p>
                    <?php endif; ?>
                    <?php do_action('woocommerce_my_account_after_my_address', $name); ?>
                </div>

                <a class="zbx-btn <?php echo $address ? 'zbx-btn--ghost' : 'zbx-btn--solid'; ?>"
                   href="<?php echo esc_url(wc_get_endpoint_url('edit-address', $name)); ?>">
                    <?php echo $address ? 'تعديل العنوان' : 'إضافة العنوان'; ?>
                </a>
            </article>
        <?php endforeach; ?>
    </div>

</section>
