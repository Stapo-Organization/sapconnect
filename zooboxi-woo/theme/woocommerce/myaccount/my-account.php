<?php
/**
 * Account shell — identity bar + navigation + content.
 *
 * @package zooboxi-child
 */

defined('ABSPATH') || exit;

$zbx_user  = wp_get_current_user();
$zbx_stats = zooboxi_account_stats($zbx_user->ID);
$zbx_tier  = $zbx_stats['tier'];
$zbx_name  = zooboxi_account_display_name($zbx_user);
$zbx_since = $zbx_stats['first_order_ts'] ?: strtotime($zbx_user->user_registered);
?>

<div class="zbx-account">

    <header class="zbx-acct-id" style="--tier-1:<?php echo esc_attr($zbx_tier['c1']); ?>;--tier-2:<?php echo esc_attr($zbx_tier['c2']); ?>">
        <div class="zbx-acct-id__glow" aria-hidden="true"></div>

        <div class="zbx-acct-id__avatar" aria-hidden="true">
            <span><?php echo esc_html(zooboxi_account_initials($zbx_user)); ?></span>
            <em class="zbx-acct-id__crest"><?php echo esc_html($zbx_tier['icon']); ?></em>
        </div>

        <div class="zbx-acct-id__who">
            <h1 class="zbx-acct-id__name"><?php echo esc_html($zbx_name); ?></h1>
            <div class="zbx-acct-id__meta">
                <span class="zbx-tier-pill"><?php echo esc_html($zbx_tier['icon'] . ' ' . $zbx_tier['name']); ?></span>
                <?php if ($zbx_since) : ?>
                    <span class="zbx-acct-id__since">عضو منذ <?php echo esc_html(zooboxi_date_ar_ts($zbx_since, false)); ?></span>
                <?php endif; ?>
            </div>
        </div>

        <?php /* On the dashboard the full KPI grid already carries these two
                 numbers — showing them here as well is pure repetition. */ ?>
        <?php if ($zbx_stats['orders_count'] > 0 && is_wc_endpoint_url()) : ?>
            <dl class="zbx-acct-id__mini">
                <div>
                    <dt>الطلبات</dt>
                    <dd><?php echo esc_html(number_format_i18n($zbx_stats['orders_count'])); ?></dd>
                </div>
                <div>
                    <dt>القطع</dt>
                    <dd><?php echo esc_html(number_format_i18n($zbx_stats['items_count'])); ?></dd>
                </div>
            </dl>
        <?php endif; ?>
    </header>

    <?php do_action('woocommerce_account_navigation'); ?>

    <div class="woocommerce-MyAccount-content">
        <?php do_action('woocommerce_account_content'); ?>
    </div>

</div>
