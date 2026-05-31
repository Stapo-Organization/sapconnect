<?php
/**
 * Checkout Customizer — saves delivery metadata to the order.
 */
class Zooboxi_Checkout_Customizer
{
    public function __construct()
    {
        add_action('woocommerce_checkout_update_order_meta', [$this, 'save_delivery_meta']);
        add_action('woocommerce_checkout_before_order_review', [$this, 'render_delivery_summary']);
    }

    public function save_delivery_meta(int $orderId): void
    {
        $session = WC()->session;
        if (!$session) return;

        $order = wc_get_order($orderId);
        if (!$order) return;

        $order->update_meta_data('_zooboxi_warehouse', $session->get('zooboxi_warehouse_code', ''));
        $order->update_meta_data('_zooboxi_delivery_type', $session->get('zooboxi_delivery_type', ''));
        $order->update_meta_data('_zooboxi_lat', $session->get('zooboxi_customer_lat', ''));
        $order->update_meta_data('_zooboxi_lng', $session->get('zooboxi_customer_lng', ''));
        $order->save();
    }

    public function render_delivery_summary(): void
    {
        $session = WC()->session;
        if (!$session) return;

        $type = $session->get('zooboxi_delivery_type', '');
        if (empty($type)) return;

        $labels = [
            'express'  => '🚀 ' . __('توصيل سريع — خلال ساعتين', 'zooboxi'),
            'same_day' => '📦 ' . __('توصيل عادي — خلال 24 ساعة', 'zooboxi'),
            'shipping' => '🚚 ' . __('شحن — 2-4 أيام عمل', 'zooboxi'),
            'pickup'   => '🏬 ' . __('استلام من الفرع', 'zooboxi'),
        ];

        $label = $labels[$type] ?? $type;
        ?>
        <div class="zooboxi-checkout-delivery" style="background:#f0f9f0;border:1px solid #2DB87B;border-radius:8px;padding:12px;margin-bottom:16px;">
            <strong><?php echo esc_html($label); ?></strong>
        </div>
        <?php
    }
}
