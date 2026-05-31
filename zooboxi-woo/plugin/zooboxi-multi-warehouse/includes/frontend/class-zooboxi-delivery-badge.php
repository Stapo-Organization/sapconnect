<?php
/**
 * Delivery Badge — shows estimated delivery time on product cards.
 */
class Zooboxi_Delivery_Badge
{
    public function __construct()
    {
        add_action('woocommerce_after_shop_loop_item_title', [$this, 'render_badge'], 15);
        add_action('woocommerce_single_product_summary', [$this, 'render_delivery_info'], 25);
    }

    /**
     * Small badge on product cards in shop loop.
     */
    public function render_badge(): void
    {
        $session = WC()->session ?? null;
        $deliveryType = $session ? $session->get('zooboxi_delivery_type') : null;

        if (!$deliveryType) return;

        $badges = [
            'express'  => ['🚀', __('توصيل خلال ساعتين', 'zooboxi'), 'express'],
            'same_day' => ['📦', __('توصيل خلال 24 ساعة', 'zooboxi'), 'standard'],
            'shipping' => ['🚚', __('شحن 2-4 أيام', 'zooboxi'), 'shipping'],
        ];

        $badge = $badges[$deliveryType] ?? $badges['shipping'];

        printf(
            '<div class="zooboxi-delivery-badge zooboxi-delivery-badge--%s">%s %s</div>',
            esc_attr($badge[2]),
            esc_html($badge[0]),
            esc_html($badge[1])
        );
    }

    /**
     * Detailed delivery info on single product page.
     */
    public function render_delivery_info(): void
    {
        $session = WC()->session ?? null;
        $lat = $session ? (float) $session->get('zooboxi_customer_lat') : 0;
        $lng = $session ? (float) $session->get('zooboxi_customer_lng') : 0;
        $city = $session ? $session->get('zooboxi_customer_city', '') : '';

        if (!$lat && !$lng && empty($city)) return;

        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng);

        ?>
        <div class="zooboxi-delivery-info">
            <div class="zooboxi-delivery-info__header">
                <span>📍</span>
                <span><?php echo esc_html(sprintf(__('التوصيل إلى: %s', 'zooboxi'), $city)); ?></span>
                <a href="#" class="zooboxi-change-location"><?php esc_html_e('تغيير', 'zooboxi'); ?></a>
            </div>
            <div class="zooboxi-delivery-info__options">
                <?php if ($options['express']): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--express">
                    <span>🚀</span>
                    <div>
                        <strong><?php esc_html_e('توصيل سريع: خلال ساعتين', 'zooboxi'); ?></strong>
                        <span class="zooboxi-delivery-fee"><?php echo $options['express']['fee'] > 0 ? esc_html($options['express']['fee'] . ' ' . __('ر.س', 'zooboxi')) : esc_html__('مجاناً', 'zooboxi'); ?></span>
                    </div>
                </div>
                <?php endif; ?>
                <?php if ($options['standard']): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--standard">
                    <span>📦</span>
                    <div>
                        <strong><?php esc_html_e('توصيل عادي: خلال 24 ساعة', 'zooboxi'); ?></strong>
                        <span class="zooboxi-delivery-fee"><?php echo $options['standard']['fee'] > 0 ? esc_html($options['standard']['fee'] . ' ' . __('ر.س', 'zooboxi')) : esc_html__('مجاناً', 'zooboxi'); ?></span>
                    </div>
                </div>
                <?php endif; ?>
                <?php if (!empty($options['pickup'])): ?>
                <div class="zooboxi-delivery-option zooboxi-delivery-option--pickup">
                    <span>🏬</span>
                    <div>
                        <strong><?php esc_html_e('استلام من الفرع: مجاناً', 'zooboxi'); ?></strong>
                    </div>
                </div>
                <?php endif; ?>
            </div>
        </div>
        <?php
    }
}
