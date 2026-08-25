<?php
/**
 * Account navigation — icon-led, scrollable on mobile, sidebar on desktop.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

do_action('woocommerce_before_account_navigation');
?>
<nav class="woocommerce-MyAccount-navigation zbx-acct-nav" aria-label="أقسام حسابي">
    <ul>
        <?php foreach (wc_get_account_menu_items() as $endpoint => $label) : ?>
            <li class="<?php echo esc_attr(wc_get_account_menu_item_classes($endpoint)); ?>">
                <a href="<?php echo esc_url(wc_get_account_endpoint_url($endpoint)); ?>"
                   <?php echo wc_is_current_account_menu_item($endpoint) ? 'aria-current="page"' : ''; ?>>
                    <span class="zbx-nav-ic" aria-hidden="true"><?php echo esc_html(zooboxi_account_menu_icon($endpoint)); ?></span>
                    <span class="zbx-nav-tx"><?php echo esc_html($label); ?></span>
                </a>
            </li>
        <?php endforeach; ?>
    </ul>
</nav>
<?php do_action('woocommerce_after_account_navigation'); ?>
