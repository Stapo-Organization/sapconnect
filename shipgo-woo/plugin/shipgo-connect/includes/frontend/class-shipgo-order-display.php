<?php
defined('ABSPATH') || exit;

/** Surfaces the ShipGo fulfilment status + tracking to the customer (account + emails). */
class ShipGo_Order_Display {

    private static ?ShipGo_Order_Display $instance = null;
    public static function instance(): ShipGo_Order_Display { return self::$instance ??= new self(); }

    public function register_hooks(): void {
        add_action('woocommerce_order_details_after_order_table', [$this, 'on_account'], 20, 1);
        add_action('woocommerce_email_order_meta', [$this, 'on_email'], 20, 4);
    }

    public function on_account(WC_Order $order): void {
        $rows = $this->rows($order);
        if (empty($rows)) { return; }
        echo '<section class="shipgo-fulfilment" style="margin-top:18px"><h2>' . esc_html__('حالة الشحنة', 'shipgo') . '</h2><table class="woocommerce-table shop_table"><tbody>';
        foreach ($rows as $label => $value) {
            echo '<tr><th>' . esc_html($label) . '</th><td>' . wp_kses_post($value) . '</td></tr>';
        }
        echo '</tbody></table></section>';
    }

    public function on_email($order, $sent_to_admin, $plain_text, $email): void {
        if (!$order instanceof WC_Order) { return; }
        $rows = $this->rows($order);
        if (empty($rows)) { return; }
        if ($plain_text) {
            foreach ($rows as $label => $value) {
                echo $label . ': ' . wp_strip_all_tags($value) . "\n";
            }
            return;
        }
        echo '<h2 style="text-align:right">' . esc_html__('حالة الشحنة', 'shipgo') . '</h2><table cellspacing="0" cellpadding="6" style="width:100%;text-align:right"><tbody>';
        foreach ($rows as $label => $value) {
            echo '<tr><th style="text-align:right">' . esc_html($label) . '</th><td>' . wp_kses_post($value) . '</td></tr>';
        }
        echo '</tbody></table>';
    }

    private function rows(WC_Order $order): array {
        $status   = $order->get_meta(ShipGo_Statuses::META_STATUS);
        $tracking = $order->get_meta(ShipGo_Statuses::META_TRACKING);
        $carrier  = $order->get_meta(ShipGo_Statuses::META_CARRIER);
        if (!$status) { return []; }
        $rows = [__('الحالة', 'shipgo') => esc_html(ShipGo_Statuses::label_ar($status))];
        if ($tracking) {
            $rows[__('رقم التتبّع', 'shipgo')] = '<span style="direction:ltr">' . esc_html($tracking) . '</span>' . ($carrier ? ' — ' . esc_html($carrier) : '');
        }
        return $rows;
    }
}
