<?php
defined('ABSPATH') || exit;

/** Seed default settings on activation. */
class ShipGo_Activator {
    public static function activate(): void {
        if (get_option('shipgo_connect_settings') === false) {
            add_option('shipgo_connect_settings', [
                'enabled'        => 'no',
                'base_url'       => '',
                'api_key'        => '',
                'webhook_secret' => '',
                'dispatch_status'=> 'completed',   // WC status to set when ShipGo dispatches
            ]);
        }
    }
}
