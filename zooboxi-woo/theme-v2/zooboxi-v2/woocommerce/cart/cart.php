<?php
/**
 * Cart page — lines grouped into the shipments they will travel in
 * (express / same-day / shipping), each with its promise; the summary on the
 * side with the free-delivery meter, coupon and totals.
 *
 * Lines are grouped by zv_item_tier() — the slowest tier of a line, planned the way
 * the plugin's Smart Shipments plans (and charges) it, basket storefront included,
 * so a card never over-promises. Quantities post
 * through WooCommerce's own cart form, so cart.js recalculates everything.
 *
 * Based on WooCommerce templates/cart/cart.php 10.x.
 */
defined('ABSPATH') || exit;

[$zv_lat, $zv_lng] = Zv_Scope::latlng();
$zv_group = class_exists('Zooboxi_Fulfillment') && ($zv_lat || $zv_lng);
$zv_groups = [];
foreach (WC()->cart->get_cart() as $key => $item) {
    $p = $item['data'] ?? null;
    if (!$p instanceof WC_Product || !$p->exists() || $item['quantity'] <= 0 || !apply_filters('woocommerce_cart_item_visible', true, $item, $key)) {
        continue;
    }
    $tier = $zv_group ? zv_item_tier($item, (float) $zv_lat, (float) $zv_lng) : 'all';
    $zv_groups[$tier][$key] = $item;
}
$order = ['express' => 1, 'same_day' => 2, 'shipping' => 3, 'all' => 4];
uksort($zv_groups, static fn($a, $b) => ($order[$a] ?? 9) <=> ($order[$b] ?? 9));

$zv_tier_head = static function (string $tier): array {
    switch ($tier) {
        case 'express':
            return [zv_bolt(18), zv_t('إكسبريس', 'Express'), zv_t('يوصلك خلال ساعتين', 'Arrives within 2 hours')];
        case 'same_day':
            $day = class_exists('Zooboxi_Fulfillment') ? Zooboxi_Fulfillment::standard_day_label() : zv_t('غدًا', 'tomorrow');
            return [zv_icon('truck', 18), zv_t('التوصيل العادي', 'Standard delivery'), sprintf(zv_t('يوصلك %s', 'Arrives %s'), $day)];
        case 'shipping':
            $p = class_exists('Zooboxi_Fulfillment') ? Zooboxi_Fulfillment::tier_presentation('shipping') : ['date' => ''];
            return [zv_icon('box', 18), zv_t('الشحن', 'Shipping'), $p['date'] ? sprintf(zv_t('يصلك %s', 'Arrives %s'), $p['date']) : zv_t('خلال 4-5 أيام عمل', 'In 4–5 working days')];
        default:
            return [zv_icon('bag', 18), zv_t('منتجاتك', 'Your items'), zv_t('حدّد موقعك لنعرض موعد التوصيل', 'Set your location to see delivery times')];
    }
};

do_action('woocommerce_before_cart'); ?>

<div class="zv-cartpage">
    <form class="woocommerce-cart-form zv-cartpage__lines" action="<?php echo esc_url(wc_get_cart_url()); ?>" method="post">
        <?php do_action('woocommerce_before_cart_table'); ?>
        <?php foreach ($zv_groups as $tier => $items) :
            [$icon, $name, $promise] = $zv_tier_head((string) $tier); ?>
            <section class="zv-shipment zv-shipment--<?php echo esc_attr((string) $tier); ?>">
                <header class="zv-shipment__head">
                    <span class="zv-shipment__ic"><?php echo $icon; // phpcs:ignore ?></span>
                    <span class="zv-shipment__txt"><strong><?php echo esc_html($name); ?></strong><span><?php echo esc_html($promise); ?></span></span>
                    <span class="zv-shipment__n"><?php echo esc_html(zv_count(count($items), zv_t('صنف واحد', '1 item'), zv_t('صنفان', '2 items'), zv_t('أصناف', 'items'), zv_t('صنفاً', 'items'))); ?></span>
                    <?php if ($tier === 'all') : ?><button type="button" class="zv-linkbtn" data-zv-open="location"><?php zv_e('حدّد موقعك', 'Set location'); ?></button><?php endif; ?>
                </header>
                <ul class="zv-lines">
                    <?php foreach ($items as $key => $item) :
                        $_product  = apply_filters('woocommerce_cart_item_product', $item['data'], $item, $key);
                        $pname     = apply_filters('woocommerce_cart_item_name', $_product->get_name(), $item, $key);
                        $permalink = apply_filters('woocommerce_cart_item_permalink', $_product->is_visible() ? $_product->get_permalink($item) : '', $item, $key);
                        $thumb     = apply_filters('woocommerce_cart_item_thumbnail', $_product->get_image('woocommerce_thumbnail'), $item, $key);
                        $max       = $_product->is_sold_individually() ? 1 : $_product->get_max_purchase_quantity();
                        $line      = (float) $item['line_subtotal'] + (float) $item['line_subtotal_tax'];
                        ?>
                        <li class="zv-line woocommerce-cart-form__cart-item <?php echo esc_attr(apply_filters('woocommerce_cart_item_class', 'cart_item', $item, $key)); ?>">
                            <div class="zv-line__img"><?php echo $permalink ? '<a href="' . esc_url($permalink) . '">' . $thumb . '</a>' : $thumb; // phpcs:ignore ?></div>
                            <div class="zv-line__info">
                                <?php echo $permalink ? '<a class="zv-line__name" href="' . esc_url($permalink) . '">' . wp_kses_post($pname) . '</a>' : '<span class="zv-line__name">' . wp_kses_post($pname) . '</span>'; // phpcs:ignore ?>
                                <?php do_action('woocommerce_after_cart_item_name', $item, $key); ?>
                                <div class="zv-line__meta"><?php echo wc_get_formatted_cart_item_data($item); // phpcs:ignore ?></div>
                                <span class="zv-line__unit"><?php echo wp_kses_post(apply_filters('woocommerce_cart_item_price', WC()->cart->get_product_price($_product), $item, $key)); ?> <?php zv_e('للقطعة', 'each'); ?></span>
                            </div>
                            <div class="zv-line__qty">
                                <div class="zv-step" data-max="<?php echo (int) ($max > 0 ? $max : 99); ?>" data-zv-cartform>
                                    <button type="button" class="zv-step__btn" data-step="1" aria-label="<?php echo esc_attr(zv_t('زيادة', 'More')); ?>"><?php echo zv_icon('plus', 16); // phpcs:ignore ?></button>
                                    <input class="zv-step__n qty" type="number" name="cart[<?php echo esc_attr($key); ?>][qty]" value="<?php echo (int) $item['quantity']; ?>" min="0" max="<?php echo (int) ($max > 0 ? $max : 99); ?>" inputmode="numeric" aria-label="<?php echo esc_attr(sprintf(zv_t('كمية %s', 'Quantity of %s'), wp_strip_all_tags($pname))); ?>">
                                    <button type="button" class="zv-step__btn" data-step="-1" aria-label="<?php echo esc_attr(zv_t('إنقاص', 'Less')); ?>"><?php echo zv_icon('minus', 16); // phpcs:ignore ?></button>
                                </div>
                                <span class="product-remove"><?php
                                    echo apply_filters('woocommerce_cart_item_remove_link', sprintf( // phpcs:ignore
                                        '<a role="button" href="%s" class="remove zv-line__remove" aria-label="%s" data-product_id="%s" data-product_sku="%s">%s<span>%s</span></a>',
                                        esc_url(wc_get_cart_remove_url($key)),
                                        esc_attr(sprintf(zv_t('إزالة %s', 'Remove %s'), wp_strip_all_tags($pname))),
                                        esc_attr((string) $item['product_id']),
                                        esc_attr($_product->get_sku()),
                                        zv_icon('trash', 16),
                                        esc_html(zv_t('حذف', 'Remove'))
                                    ), $key);
                                ?></span>
                            </div>
                            <strong class="zv-line__total"><?php echo zv_money($line); // phpcs:ignore ?></strong>
                        </li>
                    <?php endforeach; ?>
                </ul>
            </section>
        <?php endforeach; ?>

        <?php do_action('woocommerce_cart_contents'); ?>
        <div class="zv-cartpage__actions">
            <button type="submit" class="zv-sr" name="update_cart" value="<?php esc_attr_e('Update cart', 'woocommerce'); ?>"><?php esc_html_e('Update cart', 'woocommerce'); ?></button>
            <?php do_action('woocommerce_cart_actions'); ?>
            <?php wp_nonce_field('woocommerce-cart', 'woocommerce-cart-nonce'); ?>
        </div>
        <?php do_action('woocommerce_after_cart_contents'); ?>
        <?php do_action('woocommerce_after_cart_table'); ?>
    </form>

    <aside class="zv-cartpage__side">
        <?php echo zv_free_meter(); // phpcs:ignore ?>
        <?php do_action('woocommerce_before_cart_collaterals'); ?>
        <div class="cart-collaterals">
            <?php do_action('woocommerce_cart_collaterals'); ?>
        </div>
        <a class="zv-btn zv-btn--ghost zv-btn--block" href="<?php echo esc_url(home_url('/')); ?>"><?php zv_e('متابعة التسوّق', 'Continue shopping'); ?></a>
    </aside>
</div>

<?php do_action('woocommerce_after_cart');
