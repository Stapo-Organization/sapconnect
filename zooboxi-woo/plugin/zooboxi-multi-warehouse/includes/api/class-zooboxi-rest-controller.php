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

        // Per-customer homepage hydration (welcome / promise / recently-viewed /
        // buy-again / recommended / trending-in-city / login invite). Public — the
        // response is marked no-store and varies by auth cookie + location params.
        register_rest_route($this->namespace, '/home-feed', [
            'methods'             => 'GET',
            'callback'            => [new Zooboxi_Home_Feed(), 'handle'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route($this->namespace, '/sync/(?P<type>[a-z]+)', [
            'methods'             => 'POST',
            'callback'            => [$this, 'trigger_sync'],
            'permission_callback' => function () { return current_user_can('manage_woocommerce'); },
        ]);

        // Set an order's status from sapconnect / the Exhibition Manager app.
        // Authenticated with the shared zooboxi_api_token (sent in the body, so
        // it survives servers that strip the Authorization header). Runs
        // $order->update_status() server-side — full caps, fires all hooks.
        register_rest_route($this->namespace, '/orders/(?P<id>\d+)/status', [
            'methods'             => 'POST',
            'callback'            => [$this, 'update_order_status'],
            'permission_callback' => [$this, 'verify_app_token'],
            'args' => [
                'id' => ['required' => true, 'type' => 'integer', 'sanitize_callback' => 'absint'],
            ],
        ]);
    }

    /**
     * Verify the shared app token (body param preferred, Bearer header fallback).
     */
    public function verify_app_token(\WP_REST_Request $request): bool
    {
        $expected = (string) get_option('zooboxi_api_token', '');
        if ($expected === '') {
            return false;
        }

        $provided = (string) $request->get_param('token');
        if ($provided === '') {
            $auth = (string) $request->get_header('authorization');
            if ($auth && stripos($auth, 'bearer ') === 0) {
                $provided = trim(substr($auth, 7));
            }
        }

        return $provided !== '' && hash_equals($expected, $provided);
    }

    /**
     * POST /orders/{id}/status — set a WooCommerce order's status.
     *
     * Optionally carries a `mrsool` object — {order_id, status, courier_name,
     * courier_phone, tracking_url} — pushed by sapconnect whenever a Mrsool
     * (مرسول) delivery changes phase. It is entirely optional: callers that send
     * only `status` + `token` behave exactly as before.
     */
    public function update_order_status(\WP_REST_Request $request): \WP_REST_Response
    {
        $order_id = (int) $request->get_param('id');
        $status   = sanitize_text_field((string) ($request->get_param('status') ?: 'zb-ready'));
        $status   = preg_replace('/^wc-/', '', $status); // WC expects the slug without the wc- prefix

        $order = wc_get_order($order_id);
        if (!$order) {
            return new \WP_REST_Response(['status' => 'error', 'message' => 'order_not_found'], 404);
        }

        if (!array_key_exists('wc-' . $status, wc_get_order_statuses())) {
            return new \WP_REST_Response(['status' => 'error', 'message' => 'invalid_status', 'requested' => $status], 400);
        }

        // Stamp the courier meta BEFORE the transition so anything listening on
        // woocommerce_order_status_changed already sees the delivery details.
        $mrsool = ($order instanceof \WC_Order)
            ? $this->save_mrsool_meta($order, $request->get_param('mrsool'))
            : null;

        $order->update_status($status, $mrsool === null
            ? __('تم التجهيز عبر تطبيق مدير المعرض', 'zooboxi')
            : __('تحديث حالة التوصيل من مرسول', 'zooboxi'));

        return new \WP_REST_Response([
            'status'     => 'updated',
            'order_id'   => $order_id,
            'new_status' => $order->get_status(),
            'mrsool'     => $mrsool,
        ], 200);
    }

    /** Arabic labels for the 14 Mrsool LaaS statuses (used in the order note). */
    private static function mrsool_status_label(string $status): string
    {
        $map = [
            'COURIER_PENDING'     => 'بانتظار مندوب',
            'COURIER_ASSIGNED'    => 'تم تعيين مندوب',
            'COURIER_REASSIGNED'  => 'تم تغيير المندوب',
            'PICKUP_ARRIVED'      => 'المندوب وصل الفرع',
            'COLLECTING'          => 'جاري الاستلام',
            'CONFIRMED_PICKUP'    => 'تم استلام الطلب',
            'WAITING_FOR_DELIVERY' => 'بانتظار التوصيل',
            'DELIVERING'          => 'في الطريق إليك',
            'DROPOFF_ARRIVED'     => 'المندوب وصل الموقع',
            'PARTIALLY_DELIVERED' => 'تم التسليم جزئياً',
            'DELIVERED'           => 'تم التسليم',
            'RETURN'              => 'مرتجع',
            'CANCELED'            => 'ملغى',
            'EXPIRED'             => 'منتهي الصلاحية',
        ];

        return $map[$status] ?? $status;
    }

    /**
     * Persist the optional `mrsool` payload on the order and log an Arabic note.
     *
     * Returns the sanitized values that were saved, or null when the caller sent
     * nothing (or nothing usable) — never throws, never blocks the status update.
     */
    private function save_mrsool_meta(\WC_Order $order, $raw): ?array
    {
        if (is_string($raw) && $raw !== '') {
            $decoded = json_decode($raw, true); // tolerate form-encoded callers
            $raw     = is_array($decoded) ? $decoded : null;
        }
        if (!is_array($raw) || $raw === []) {
            return null;
        }

        $mrsool_id     = isset($raw['order_id']) ? absint($raw['order_id']) : 0;
        $mrsool_status = isset($raw['status']) ? sanitize_text_field((string) $raw['status']) : '';
        $courier_name  = isset($raw['courier_name']) ? sanitize_text_field((string) $raw['courier_name']) : '';
        $courier_phone = isset($raw['courier_phone']) ? sanitize_text_field((string) $raw['courier_phone']) : '';
        $tracking_url  = isset($raw['tracking_url']) ? esc_url_raw((string) $raw['tracking_url']) : '';

        if ($mrsool_id <= 0 && $mrsool_status === '') {
            return null; // nothing identifiable — ignore rather than write empty meta
        }

        $previous_status  = (string) $order->get_meta('_mrsool_status');
        $previous_courier = (string) $order->get_meta('_mrsool_courier_name');

        if ($mrsool_id > 0) {
            $order->update_meta_data('_mrsool_order_id', $mrsool_id);
        }
        if ($mrsool_status !== '') {
            $order->update_meta_data('_mrsool_status', $mrsool_status);
        }
        if ($courier_name !== '') {
            $order->update_meta_data('_mrsool_courier_name', $courier_name);
        }
        if ($courier_phone !== '') {
            $order->update_meta_data('_mrsool_courier_phone', $courier_phone);
        }
        if ($tracking_url !== '') {
            $order->update_meta_data('_mrsool_tracking_url', $tracking_url);
        }
        $order->save_meta_data();

        // Real movement is worth telling the customer about, not only the
        // order note. Fired before the note so a listener that throws cannot
        // leave the note unwritten — and fired only on a change, because the
        // backend re-pushes the same phase on every sync.
        if ($mrsool_status !== '' && $mrsool_status !== $previous_status) {
            do_action('zooboxi_mrsool_status_changed', $order, $mrsool_status, $previous_status, $courier_name);
        }

        // Only note real movement — the backend may re-push the same phase.
        if ($mrsool_status !== '' && ($mrsool_status !== $previous_status || $courier_name !== $previous_courier)) {
            $note = sprintf(
                /* translators: 1: Arabic Mrsool status label, 2: Mrsool order id */
                __('مرسول: %1$s (رقم الطلب لدى مرسول: %2$s)', 'zooboxi'),
                self::mrsool_status_label($mrsool_status),
                $mrsool_id > 0 ? (string) $mrsool_id : '—'
            );
            if ($courier_name !== '') {
                $note .= ' — ' . sprintf(__('المندوب: %s', 'zooboxi'), $courier_name);
                if ($courier_phone !== '') {
                    $note .= ' (' . $courier_phone . ')';
                }
            }
            $order->add_order_note($note);
        }

        return [
            'order_id'      => $mrsool_id ?: (int) $order->get_meta('_mrsool_order_id'),
            'status'        => $mrsool_status !== '' ? $mrsool_status : $previous_status,
            'courier_name'  => $courier_name,
            'courier_phone' => $courier_phone,
            'tracking_url'  => $tracking_url,
        ];
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
