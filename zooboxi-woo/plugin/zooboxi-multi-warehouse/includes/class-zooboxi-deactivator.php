<?php
/**
 * Plugin Deactivator — clears cron events.
 */
class Zooboxi_Deactivator
{
    public static function deactivate(): void
    {
        wp_clear_scheduled_hook('zooboxi_sync_stock');
        wp_clear_scheduled_hook('zooboxi_sync_products');
        wp_clear_scheduled_hook('zooboxi_sync_prices');
        flush_rewrite_rules();
    }
}
