<?php
/**
 * REST API Controller — public endpoints for the frontend.
 */
class Zooboxi_Rest_Controller extends WP_REST_Controller
{
    protected $namespace = 'zooboxi/v1';

    public function register_routes(): void
    {
        register_rest_route($this->namespace, '/detect-warehouse', [
            'methods'             => 'POST',
            'callback'            => [$this, 'detect_warehouse'],
            'permission_callback' => '__return_true',
            'args' => [
                'lat' => ['required' => true, 'type' => 'number', 'sanitize_callback' => 'floatval'],
                'lng' => ['required' => true, 'type' => 'number', 'sanitize_callback' => 'floatval'],
            ],
        ]);

        register_rest_route($this->namespace, '/delivery-options', [
            'methods'             => 'POST',
            'callback'            => [$this, 'get_delivery_options'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route($this->namespace, '/pickup-locations', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_pickup_locations'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route($this->namespace, '/cities', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_cities'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route($this->namespace, '/sync/(?P<type>[a-z]+)', [
            'methods'             => 'POST',
            'callback'            => [$this, 'trigger_sync'],
            'permission_callback' => function () { return current_user_can('manage_woocommerce'); },
        ]);
    }

    public function detect_warehouse(\WP_REST_Request $request): \WP_REST_Response
    {
        $lat = (float) $request->get_param('lat');
        $lng = (float) $request->get_param('lng');

        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng);

        // Save to session
        if (function_exists('WC') && WC()->session) {
            WC()->session->set('zooboxi_customer_lat', $lat);
            WC()->session->set('zooboxi_customer_lng', $lng);
            $best = $options['express'] ?? $options['standard'] ?? $options['shipping'] ?? null;
            if ($best) {
                WC()->session->set('zooboxi_warehouse_code', $best['warehouse_code']);
                WC()->session->set('zooboxi_delivery_type', $best['delivery_type']);
            }
        }

        return rest_ensure_response($options);
    }

    public function get_delivery_options(\WP_REST_Request $request): \WP_REST_Response
    {
        $lat = (float) $request->get_param('lat');
        $lng = (float) $request->get_param('lng');
        return rest_ensure_response(Zooboxi_Delivery_Engine::detect_options($lat, $lng));
    }

    public function get_pickup_locations(): \WP_REST_Response
    {
        $session = WC()->session ?? null;
        $lat = $session ? (float) $session->get('zooboxi_customer_lat') : 24.7136;
        $lng = $session ? (float) $session->get('zooboxi_customer_lng') : 46.6753;
        return rest_ensure_response(Zooboxi_Warehouse_Manager::get_pickup_locations($lat, $lng));
    }

    public function get_cities(): \WP_REST_Response
    {
        return rest_ensure_response(Zooboxi_Location_Detector::get_available_cities());
    }

    public function trigger_sync(\WP_REST_Request $request): \WP_REST_Response
    {
        $type = $request->get_param('type');
        $engine = new Zooboxi_Sync_Engine();

        $result = match ($type) {
            'products'   => $engine->sync_products(),
            'stock'      => $engine->sync_stock(),
            'prices'     => $engine->sync_prices(),
            'warehouses' => $engine->sync_warehouses(),
            default      => ['error' => 'Invalid sync type'],
        };

        return rest_ensure_response($result);
    }
}
