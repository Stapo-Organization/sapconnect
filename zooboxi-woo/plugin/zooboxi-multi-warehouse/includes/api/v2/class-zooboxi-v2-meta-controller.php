<?php
/**
 * Zooboxi_V2_Meta_Controller — the app's boot handshake.
 *
 * One cheap, cacheable call the app makes on launch: the minimum supported build (the
 * force-update gate), the live shipping thresholds and fees so the app never hardcodes
 * money, and the feature flags that decide which screens it shows.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Meta_Controller
{
    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/meta', 'GET', [$this, 'meta']);
    }

    public function meta(\WP_REST_Request $request): \WP_REST_Response
    {
        return Zooboxi_V2_Bootstrap::ok([
            'min_app_version' => [
                'ios'     => (string) get_option('zooboxi_min_app_ios', '0.0.0'),
                'android' => (string) get_option('zooboxi_min_app_android', '0.0.0'),
            ],
            'free_shipping_min' => (float) get_option('zooboxi_free_shipping_min', 200),
            'fees' => [
                'express'  => (float) get_option('zooboxi_express_fee', 15),
                'standard' => (float) get_option('zooboxi_standard_fee', 10),
                'shipping' => (float) get_option('zooboxi_shipping_fee', 25),
            ],
            'currency' => 'SAR',
            'features' => [
                'smart_shipments' => get_option('zooboxi_smart_shipments', 'no') === 'yes',
                'wishlist'        => true,
                'clearance'       => get_option('zooboxi_clearance_collection', 'yes') === 'yes',
                'badges'          => get_option('zooboxi_dynamic_badges', 'yes') === 'yes',
            ],
            'maintenance' => get_option('zooboxi_v2_maintenance', 'no') === 'yes',
            'lang'        => Zooboxi_V2_Bootstrap::lang(),
        ], Zooboxi_V2_Bootstrap::TTL_META);
    }
}
