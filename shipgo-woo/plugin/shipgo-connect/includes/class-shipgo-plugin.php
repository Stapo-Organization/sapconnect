<?php
/**
 * Singleton bootstrap — wires the order capture, the status-callback receiver,
 * the admin settings page, the order metabox, the WP-Cron retry queue, and the
 * customer-facing status/tracking display.
 */
defined('ABSPATH') || exit;

final class ShipGo_Plugin {

    private static ?ShipGo_Plugin $instance = null;

    public static function instance(): ShipGo_Plugin {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    private function __construct() {
        // outbound: capture WC orders → push to ShipGo (async + retry queue)
        ShipGo_Order_Sync::instance()->register_hooks();

        // inbound: receive HMAC-signed status callbacks from ShipGo
        add_action('rest_api_init', ['ShipGo_Webhook_Controller', 'register_routes']);

        // customer-facing status + tracking
        ShipGo_Order_Display::instance()->register_hooks();

        if (is_admin()) {
            ShipGo_Settings_Page::instance()->register_hooks();
            ShipGo_Order_Metabox::instance()->register_hooks();
        }

        load_plugin_textdomain('shipgo', false, dirname(SHIPGO_PLUGIN_BASENAME) . '/languages');
    }
}
