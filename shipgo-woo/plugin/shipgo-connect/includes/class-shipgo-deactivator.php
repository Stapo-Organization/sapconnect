<?php
defined('ABSPATH') || exit;

/** Clear scheduled retry events on deactivation. */
class ShipGo_Deactivator {
    public static function deactivate(): void {
        wp_clear_scheduled_hook('shipgo_push_order');
    }
}
