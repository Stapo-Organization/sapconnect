<?php
/**
 * Orders — a scannable card list instead of a cramped responsive table.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

do_action('woocommerce_before_account_orders', $has_orders);
?>

<section class="zbx-orders">

    <?php if ($has_orders) : ?>

        <ul class="zbx-order-list">
            <?php foreach ($customer_orders->orders as $customer_order) :
                $order  = wc_get_order($customer_order);
                if (!$order instanceof WC_Order) {
                    continue;
                }
                $status  = $order->get_status();
                $created = $order->get_date_created();
                $count   = $order->get_item_count() - $order->get_item_count_refunded();
                $dtype   = (string) $order->get_meta('_zooboxi_delivery_type');
                [$dic, $dlabel] = zooboxi_delivery_type_ar($dtype);
                $actions = wc_get_account_orders_actions($order);
                $is_open = in_array($status, zooboxi_account_open_statuses(), true);
                ?>
                <li class="zbx-order <?php echo $is_open ? 'is-open' : ''; ?>">

                    <a class="zbx-order__thumbs" href="<?php echo esc_url($order->get_view_order_url()); ?>"
                       aria-label="عرض تفاصيل الطلب رقم <?php echo esc_attr($order->get_order_number()); ?>">
                        <?php
                        $shown = 0;
                        foreach ($order->get_items() as $item) {
                            if ($shown >= 3 || !$item instanceof WC_Order_Item_Product) {
                                continue;
                            }
                            $p = $item->get_product();
                            if (!$p) {
                                continue;
                            }
                            echo '<span class="zbx-order__thumb">' . wp_kses_post($p->get_image('woocommerce_gallery_thumbnail')) . '</span>';
                            $shown++;
                        }
                        if ($count > $shown) {
                            // dir=ltr, else bidi flips "+2" into "2+"
                            echo '<span class="zbx-order__more" dir="ltr">+' . esc_html((int) ($count - $shown)) . '</span>';
                        }
                        if (!$shown) {
                            echo '<span class="zbx-order__thumb zbx-order__thumb--empty" aria-hidden="true">🧾</span>';
                        }
                        ?>
                    </a>

                    <div class="zbx-order__body">
                        <div class="zbx-order__top">
                            <a class="zbx-order__no" href="<?php echo esc_url($order->get_view_order_url()); ?>">
                                طلب <span>#<?php echo esc_html($order->get_order_number()); ?></span>
                            </a>
                            <span class="zbx-pill zbx-pill--<?php echo esc_attr(zooboxi_status_tone($status)); ?>">
                                <?php echo esc_html(zooboxi_status_ar($status)); ?>
                            </span>
                        </div>

                        <div class="zbx-order__meta">
                            <?php if ($created) : ?>
                                <time datetime="<?php echo esc_attr($created->date('c')); ?>">
                                    <?php echo esc_html(zooboxi_date_ar_ts($created->getTimestamp())); ?>
                                </time>
                            <?php endif; ?>
                            <span><?php echo esc_html(zooboxi_count_ar((int) $count, 'صنف واحد', 'صنفان', 'أصناف', 'صنفاً')); ?></span>
                            <?php if ($dtype) : ?>
                                <span class="zbx-order__ship"><?php echo esc_html($dic . ' ' . $dlabel); ?></span>
                            <?php endif; ?>
                        </div>

                        <div class="zbx-order__foot">
                            <span class="zbx-order__total"><?php echo wp_kses_post($order->get_formatted_order_total()); ?></span>

                            <span class="zbx-order__actions">
                                <?php foreach ($actions as $key => $action) : ?>
                                    <a href="<?php echo esc_url($action['url']); ?>"
                                       class="zbx-obtn zbx-obtn--<?php echo esc_attr($key); ?>"><?php echo esc_html($action['name']); ?></a>
                                <?php endforeach; ?>

                                <?php if (in_array($status, ['completed', 'zb-ready'], true)) : ?>
                                    <button type="button" class="zbx-obtn zbx-obtn--reorder"
                                            data-order="<?php echo esc_attr($order->get_id()); ?>">
                                        <span aria-hidden="true">🔁</span> أعد الطلب
                                    </button>
                                <?php endif; ?>
                            </span>
                        </div>
                    </div>

                </li>
            <?php endforeach; ?>
        </ul>

        <?php if (1 < $customer_orders->max_num_pages) : ?>
            <nav class="zbx-order-pager" aria-label="صفحات الطلبات">
                <?php if (1 !== $current_page) : ?>
                    <a class="zbx-obtn" href="<?php echo esc_url(wc_get_endpoint_url('orders', $current_page - 1)); ?>">→ الأحدث</a>
                <?php endif; ?>
                <span class="zbx-order-pager__at">صفحة <?php echo esc_html($current_page); ?> من <?php echo esc_html($customer_orders->max_num_pages); ?></span>
                <?php if (intval($customer_orders->max_num_pages) !== $current_page) : ?>
                    <a class="zbx-obtn" href="<?php echo esc_url(wc_get_endpoint_url('orders', $current_page + 1)); ?>">الأقدم ←</a>
                <?php endif; ?>
            </nav>
        <?php endif; ?>

    <?php else : ?>

        <div class="zbx-empty">
            <span class="zbx-empty__ic" aria-hidden="true">🧾</span>
            <h2>لا توجد طلبات بعد</h2>
            <p>أول طلب لك يبدأ من هنا — توصيل خلال ساعتين داخل الرياض.</p>
            <a class="zbx-btn zbx-btn--solid" href="<?php echo esc_url(wc_get_page_permalink('shop')); ?>">تصفّح المتجر</a>
        </div>

    <?php endif; ?>

</section>

<?php do_action('woocommerce_after_account_orders', $has_orders); ?>
