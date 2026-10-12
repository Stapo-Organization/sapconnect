<?php
defined('ABSPATH') || exit;

/** Shows ShipGo fulfilment status + tracking on the order edit screen, with a re-push action. */
class ShipGo_Order_Metabox {

    private static ?ShipGo_Order_Metabox $instance = null;
    public static function instance(): ShipGo_Order_Metabox { return self::$instance ??= new self(); }

    public function register_hooks(): void {
        add_action('add_meta_boxes', [$this, 'add']);
        add_action('admin_post_shipgo_repush', [$this, 'repush']);
    }

    public function add(): void {
        // HPOS-aware screen id
        $screen = class_exists(\Automattic\WooCommerce\Internal\DataStores\Orders\CustomOrdersTableController::class)
            && wc_get_container()->get(\Automattic\WooCommerce\Internal\DataStores\Orders\CustomOrdersTableController::class)->custom_orders_table_usage_is_enabled()
            ? wc_get_page_screen_id('shop-order')
            : 'shop_order';
        add_meta_box('shipgo_fulfilment', __('ShipGo — التنفيذ', 'shipgo'), [$this, 'render'], $screen, 'side', 'high');
    }

    public function render($post_or_order): void {
        $order = $post_or_order instanceof WC_Order ? $post_or_order : wc_get_order($post_or_order->ID ?? 0);
        if (!$order) { return; }
        $code     = $order->get_meta(ShipGo_Statuses::META_CODE);
        $status   = $order->get_meta(ShipGo_Statuses::META_STATUS);
        $tracking = $order->get_meta(ShipGo_Statuses::META_TRACKING);
        $carrier  = $order->get_meta(ShipGo_Statuses::META_CARRIER);
        $synced   = $order->get_meta(ShipGo_Statuses::META_SYNCED);

        echo '<div dir="rtl" style="font-size:13px;line-height:1.9">';
        if (!$code) {
            echo '<p style="color:#646970">' . esc_html__('لم يُرسل هذا الطلب إلى ShipGo بعد.', 'shipgo') . '</p>';
        } else {
            echo '<p><strong>' . esc_html__('الرقم في ShipGo:', 'shipgo') . '</strong> <code class="ltr">' . esc_html($code) . '</code></p>';
            if ($status) {
                echo '<p><strong>' . esc_html__('الحالة:', 'shipgo') . '</strong> ' . esc_html(ShipGo_Statuses::label_ar($status)) . '</p>';
            }
            if ($tracking) {
                echo '<p><strong>' . esc_html__('التتبّع:', 'shipgo') . '</strong> <span class="ltr">' . esc_html($tracking) . '</span>' . ($carrier ? ' — ' . esc_html($carrier) : '') . '</p>';
            }
            if ($synced) {
                echo '<p style="color:#646970;font-size:12px">' . esc_html__('آخر مزامنة:', 'shipgo') . ' ' . esc_html($synced) . '</p>';
            }
        }
        $url = wp_nonce_url(admin_url('admin-post.php?action=shipgo_repush&order_id=' . $order->get_id()), 'shipgo_repush_' . $order->get_id());
        echo '<a href="' . esc_url($url) . '" class="button button-small">' . esc_html__('إعادة الإرسال إلى ShipGo', 'shipgo') . '</a>';
        echo '</div>';
    }

    public function repush(): void {
        $order_id = (int) ($_GET['order_id'] ?? 0);
        if (!current_user_can('manage_woocommerce') || !wp_verify_nonce($_GET['_wpnonce'] ?? '', 'shipgo_repush_' . $order_id)) {
            wp_die('forbidden');
        }
        ShipGo_Order_Sync::instance()->repush($order_id);
        wp_safe_redirect(wp_get_referer() ?: admin_url('admin.php?page=wc-orders'));
        exit;
    }
}
