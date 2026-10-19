<?php
/**
 * Plugin Name: Zooboxi — ask for a review when an order is completed
 * Description: Adds «قيّم مشترياتك» to WooCommerce's «Completed order» email, linking each product (up to four) to its review form. Only buyers can review, so every rating on the store is a real one.
 */

defined('ABSPATH') || exit;

add_action('woocommerce_email_after_order_table', static function ($order, $sent_to_admin, $plain_text, $email = null) {
    if ($sent_to_admin || !($order instanceof WC_Order) || !is_object($email) || ($email->id ?? '') !== 'customer_completed_order') {
        return;
    }
    $links = [];
    foreach ($order->get_items() as $item) {
        if (!($item instanceof WC_Order_Item_Product)) {
            continue;
        }
        $pid = (int) $item->get_product_id();
        if (!$pid || isset($links[$pid]) || get_post_status($pid) !== 'publish') {
            continue;
        }
        $links[$pid] = [wp_strip_all_tags($item->get_name()), add_query_arg('review', '1', get_permalink($pid)) . '#reviews'];
        if (count($links) >= 4) {
            break;
        }
    }
    if (!$links) {
        return;
    }
    if ($plain_text) {
        echo "\n\nقيّم مشترياتك — رأيك يساعد غيرك يختار لأليفه:\n";
        foreach ($links as [$name, $url]) {
            echo '- ' . $name . ': ' . esc_url_raw($url) . "\n";
        }
        return;
    }
    echo '<div style="margin:24px 0;padding:16px 18px;border-radius:12px;background:#fff8ef;border:1px solid #f0e2cf;text-align:right" dir="rtl">';
    echo '<h3 style="margin:0 0 6px;font-size:17px">قيّم مشترياتك</h3>';
    echo '<p style="margin:0 0 10px">رأيك يساعد غيرك يختار لأليفه، ودقيقة وحدة تكفي.</p><ul style="margin:0;padding-right:18px">';
    foreach ($links as [$name, $url]) {
        echo '<li style="margin:4px 0"><a href="' . esc_url($url) . '">' . esc_html($name) . '</a></li>';
    }
    echo '</ul></div>';
}, 20, 4);
