<?php
/**
 * Zooboxi_V2_Orders_Controller — order history, detail timeline and one-tap reorder.
 *
 * The timeline is built from `_zb_status_{status}_at` stamps written by the additive
 * hook in Zooboxi_V2_Bootstrap, so it shows the branch's real preparation moments
 * ("جاهز للتسليم" is set by the staff app via the WooCommerce REST API) rather than a
 * guessed progress bar. Tracking, when present, comes from the ShipGo connector's order
 * meta so the customer sees the same number the account page and emails show.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Orders_Controller
{
    private const PER_PAGE = 10;

    /** ShipGo connector order meta (shipgo-connect → ShipGo_Statuses). */
    private const SHIPGO_TRACKING = '_shipgo_tracking';
    private const SHIPGO_CARRIER  = '_shipgo_carrier';
    private const SHIPGO_STATUS   = '_shipgo_status';

    /** Mrsool (مرسول) express courier meta, written by Zooboxi_Rest_Controller. */
    private const MRSOOL_ORDER_ID      = '_mrsool_order_id';
    private const MRSOOL_STATUS        = '_mrsool_status';
    private const MRSOOL_COURIER_NAME  = '_mrsool_courier_name';
    private const MRSOOL_COURIER_PHONE = '_mrsool_courier_phone';
    private const MRSOOL_TRACKING_URL  = '_mrsool_tracking_url';

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/orders', 'GET', [$this, 'index']);
        Zooboxi_V2_Bootstrap::route('/orders/active', 'GET', [$this, 'active']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)', 'GET', [$this, 'show']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)/reorder', 'POST', [$this, 'reorder']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)/live-tracking', 'GET', [$this, 'live_tracking']);
    }

    /* ── GET /orders ───────────────────────────────── */

    public function index(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $page     = max(1, (int) $request->get_param('page'));
        $per_page = self::PER_PAGE;

        $query = wc_get_orders([
            'customer_id' => $user_id,
            'limit'       => $per_page,
            'paged'       => $page,
            'orderby'     => 'date',
            'order'       => 'DESC',
            'paginate'    => true,
        ]);

        $orders = is_object($query) ? ($query->orders ?? []) : (array) $query;

        $out = [];
        foreach ($orders as $order) {
            if ($order instanceof \WC_Order) {
                $out[] = $this->list_dto($order);
            }
        }

        return Zooboxi_V2_Bootstrap::ok([
            'orders' => $out,
            'page'   => $page,
            'pages'  => is_object($query) ? (int) ($query->max_num_pages ?? 1) : 1,
            'total'  => is_object($query) ? (int) ($query->total ?? count($out)) : count($out),
        ]);
    }

    /* ── GET /orders/{id} ──────────────────────────── */

    public function show(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!get_current_user_id()) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        $order = $this->owned_order($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }

        $items = [];
        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            $product = $item->get_product();
            $items[] = [
                'product_id'   => (int) $item->get_product_id(),
                'variation_id' => (int) $item->get_variation_id(),
                'name'         => wp_strip_all_tags($item->get_name()),
                'image'        => $product ? Zooboxi_Product_DTO::image_url($product, 'woocommerce_thumbnail') : null,
                'qty'          => (int) $item->get_quantity(),
                'line_total'   => (float) $item->get_total(),
            ];
        }

        return Zooboxi_V2_Bootstrap::ok($this->list_dto($order) + [
            'items'    => $items,
            'address'  => [
                'name'         => trim($order->get_shipping_first_name() . ' ' . $order->get_shipping_last_name()) ?: $order->get_formatted_billing_full_name(),
                'phone'        => (string) $order->get_billing_phone(),
                'city'         => (string) ($order->get_shipping_city() ?: $order->get_billing_city()),
                'district'     => (string) ($order->get_shipping_address_2() ?: $order->get_billing_address_2()),
                'address_line' => (string) ($order->get_shipping_address_1() ?: $order->get_billing_address_1()),
                'lat'          => (float) $order->get_meta('_zooboxi_checkout_lat'),
                'lng'          => (float) $order->get_meta('_zooboxi_checkout_lng'),
            ],
            'totals'   => [
                'subtotal' => (float) $order->get_subtotal(),
                'discount' => (float) $order->get_discount_total(),
                'shipping' => (float) $order->get_shipping_total(),
                'tax'      => (float) $order->get_total_tax(),
                'total'    => (float) $order->get_total(),
                'currency' => 'SAR',
            ],
            'timeline' => $this->timeline($order),
            'tracking' => $this->tracking($order),
            'notes'    => (string) $order->get_customer_note(),
            'loyalty'  => $this->loyalty($order),
        ]);
    }

    /**
     * What «عائلة زوبوكسي» did with this order: the paws it actually paid (null until
     * it is delivered), the scratch card it produced, and the gifts it carried.
     *
     * Returns null when the module is off, so the app can hide the section entirely.
     */
    private function loyalty(\WC_Order $order): ?array
    {
        if (!class_exists('Zooboxi_Loyalty') || !Zooboxi_Loyalty::is_enabled()) {
            return null;
        }

        try {
            $user_id = (int) $order->get_customer_id();
            $earned  = $user_id > 0
                ? Zooboxi_Loyalty_Ledger::entry_delta($user_id, 'order_earn', 'order', (int) $order->get_id())
                : 0;

            $card = Zooboxi_Loyalty_Scratch::by_order((int) $order->get_id());

            $gifts = [];
            foreach ($order->get_items() as $item) {
                if ($item instanceof \WC_Order_Item_Product
                    && (string) $item->get_meta(Zooboxi_Loyalty::ORDER_GRANT_META) !== '') {
                    $gifts[] = wp_strip_all_tags($item->get_name());
                }
            }

            return [
                'paws_earned'     => $earned > 0 ? $earned : null,
                'scratch_card_id' => $card ? (int) $card['id'] : null,
                'gift_lines'      => $gifts,
            ];
        } catch (\Throwable $e) {
            error_log('[Zooboxi v2] order loyalty block failed: ' . $e->getMessage());
            return null;
        }
    }

    /* ── POST /orders/{id}/reorder ─────────────────── */

    public function reorder(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!get_current_user_id()) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }
        $order = $this->owned_order($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('تعذّر العثور على الطلب', 'zooboxi'), 'Order not found.', 404);
        }
        if (!Zooboxi_V2_Cart_Controller::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::fail('cart_unavailable', __('السلة غير متاحة حالياً', 'zooboxi'), 'The cart is unavailable right now.', 503);
        }

        $added   = 0;
        $missing = [];

        foreach ($order->get_items() as $item) {
            if (!($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            $product = $item->get_product();
            if (!$product || !$product->is_purchasable() || !$product->is_in_stock()) {
                $missing[] = wp_strip_all_tags($item->get_name());
                continue;
            }
            try {
                $ok = WC()->cart->add_to_cart(
                    (int) $item->get_product_id(),
                    max(1, (int) $item->get_quantity()),
                    (int) $item->get_variation_id()
                );
            } catch (\Throwable $e) {
                $ok = false;
            }
            if ($ok) {
                $added++;
            } else {
                $missing[] = wp_strip_all_tags($item->get_name());
            }
        }

        if (!$added) {
            return Zooboxi_V2_Bootstrap::fail(
                'reorder_unavailable',
                __('أصناف هذا الطلب غير متوفرة حالياً', 'zooboxi'),
                'None of the items in that order are available right now.',
                409,
                ['missing' => $missing]
            );
        }

        WC()->cart->calculate_totals();

        return Zooboxi_V2_Bootstrap::ok(Zooboxi_V2_Cart_Controller::cart_dto([
            'added'   => $added,
            'missing' => $missing,
        ]));
    }

    /* ══════════════════════════════════════════════════════════════
       DTOs
       ══════════════════════════════════════════════════════════════ */

    private function list_dto(\WC_Order $order): array
    {
        $preview = [];
        foreach ($order->get_items() as $item) {
            if (count($preview) >= 3 || !($item instanceof \WC_Order_Item_Product)) {
                continue;
            }
            $product   = $item->get_product();
            $preview[] = [
                'name'  => wp_strip_all_tags($item->get_name()),
                'image' => $product ? Zooboxi_Product_DTO::image_url($product, 'woocommerce_thumbnail') : null,
                'qty'   => (int) $item->get_quantity(),
            ];
        }

        $created = $order->get_date_created();
        $status  = (string) $order->get_status();

        return [
            'id'            => $order->get_id(),
            'number'        => (string) $order->get_order_number(),
            'order_key'     => (string) $order->get_order_key(),
            'date'          => $created ? $created->date(DATE_ATOM) : null,
            'status'        => $status,
            'status_label'  => self::status_label($status),
            'total'         => (float) $order->get_total(),
            'currency'      => 'SAR',
            'is_paid'       => (bool) $order->is_paid(),
            'payment_method' => (string) $order->get_payment_method(),
            'delivery_type' => (string) $order->get_meta('_zooboxi_delivery_type'),
            'items_preview' => $preview,
            'items_count'   => (int) $order->get_item_count(),
            'can_reorder'   => in_array($status, ['completed', 'processing', 'zb-ready', 'zb-out-for-delivery', 'cancelled', 'refunded'], true),
        ];
    }

    /** Bilingual status labels, including the store's own `zb-ready`. */
    public static function status_label(string $status): string
    {
        $status = preg_replace('/^wc-/', '', $status);

        $map = [
            'pending'    => ['بانتظار الدفع', 'Pending payment'],
            'processing' => ['قيد التجهيز', 'Preparing'],
            'zb-ready'   => ['جاهز للتسليم', 'Ready for pickup-delivery'],
            'zb-out-for-delivery' => ['في الطريق إليك', 'Out for delivery'],
            'on-hold'    => ['قيد المراجعة', 'On hold'],
            'completed'  => ['مكتمل', 'Completed'],
            'cancelled'  => ['ملغى', 'Cancelled'],
            'refunded'   => ['مسترجع', 'Refunded'],
            'failed'     => ['فشل الدفع', 'Payment failed'],
        ];

        if (isset($map[$status])) {
            return Zooboxi_V2_Bootstrap::pick($map[$status][0], $map[$status][1]);
        }
        return function_exists('wc_get_order_status_name') ? (string) wc_get_order_status_name($status) : $status;
    }

    /**
     * placed → paid → preparing → ready → [out for delivery] → completed, each with the
     * moment it happened (from the `_zb_status_{status}_at` stamps) and whether it is done.
     * The courier leg only appears for orders that actually have one (Mrsool express).
     */
    private function timeline(\WC_Order $order): array
    {
        $status  = (string) $order->get_status();
        $created = $order->get_date_created();
        $paid    = $order->get_date_paid();

        $stamp = static function (\WC_Order $order, string $status): ?string {
            $value = (string) $order->get_meta('_zb_status_' . $status . '_at');
            return $value !== '' ? mysql2date(DATE_ATOM, $value, false) : null;
        };

        $ready_at     = $stamp($order, 'zb-ready');
        $preparing_at = $stamp($order, 'processing');
        $on_way_at    = $stamp($order, 'zb-out-for-delivery');
        $completed_at = $stamp($order, 'completed');
        if ($completed_at === null && $order->get_date_completed()) {
            $completed_at = $order->get_date_completed()->date(DATE_ATOM);
        }

        $rank = [
            'pending'             => 0,
            'failed'              => 0,
            'on-hold'             => 1,
            'processing'          => 2,
            'zb-ready'            => 3,
            'zb-out-for-delivery' => 4,
            'completed'           => 5,
        ];
        $now  = $rank[$status] ?? 0;

        // The courier leg is only part of the story for express orders handled by
        // Mrsool — shipped orders keep the original five-step timeline.
        $has_courier_leg = $on_way_at !== null
            || $status === 'zb-out-for-delivery'
            || (string) $order->get_meta(self::MRSOOL_ORDER_ID) !== '';

        $steps = [
            [
                'key'   => 'placed',
                'label' => Zooboxi_V2_Bootstrap::pick(__('تم استلام الطلب', 'zooboxi'), 'Order placed'),
                'at'    => $created ? $created->date(DATE_ATOM) : null,
                'done'  => true,
            ],
            [
                'key'   => 'paid',
                'label' => Zooboxi_V2_Bootstrap::pick(__('تم الدفع', 'zooboxi'), 'Paid'),
                'at'    => $paid ? $paid->date(DATE_ATOM) : null,
                'done'  => (bool) $order->is_paid(),
            ],
            [
                'key'   => 'preparing',
                'label' => Zooboxi_V2_Bootstrap::pick(__('قيد التجهيز', 'zooboxi'), 'Preparing'),
                'at'    => $preparing_at,
                'done'  => $now >= 2,
            ],
            [
                'key'   => 'ready',
                'label' => Zooboxi_V2_Bootstrap::pick(__('جاهز للتسليم', 'zooboxi'), 'Ready for pickup-delivery'),
                'at'    => $ready_at,
                'done'  => $now >= 3,
            ],
        ];

        if ($has_courier_leg) {
            $steps[] = [
                'key'   => 'out_for_delivery',
                'label' => Zooboxi_V2_Bootstrap::pick(__('في الطريق إليك', 'zooboxi'), 'Out for delivery'),
                'at'    => $on_way_at,
                'done'  => $now >= 4,
            ];
        }

        $steps[] = [
            'key'   => 'completed',
            'label' => Zooboxi_V2_Bootstrap::pick(__('تم التسليم', 'zooboxi'), 'Delivered'),
            'at'    => $completed_at,
            'done'  => $now >= 5,
        ];

        return $steps;
    }

    /**
     * Mrsool courier tracking first (express last-mile), otherwise the ShipGo
     * tracking the fulfilment connector has stamped.
     */
    private function tracking(\WC_Order $order): ?array
    {
        $mrsool_id = (string) $order->get_meta(self::MRSOOL_ORDER_ID);
        if ($mrsool_id !== '') {
            $courier_name  = (string) $order->get_meta(self::MRSOOL_COURIER_NAME);
            $courier_phone = (string) $order->get_meta(self::MRSOOL_COURIER_PHONE);
            $url           = (string) $order->get_meta(self::MRSOOL_TRACKING_URL);

            return [
                'number'        => $mrsool_id,
                'carrier'       => 'mrsool',
                'carrier_label' => 'مرسول',
                'url'           => $url !== '' ? $url : null,
                'status'        => (string) $order->get_meta(self::MRSOOL_STATUS),
                'courier'       => [
                    'name'  => $courier_name !== '' ? $courier_name : null,
                    'phone' => $courier_phone !== '' ? $courier_phone : null,
                ],
            ];
        }

        $number = (string) $order->get_meta(self::SHIPGO_TRACKING);
        if ($number === '') {
            return null;
        }

        $carrier = (string) $order->get_meta(self::SHIPGO_CARRIER);

        return [
            'number'  => $number,
            'carrier' => $carrier,
            // No carrier deep-link is stored by the connector; a filter lets one be added
            // later without another deploy of the app.
            'url'     => apply_filters('zooboxi_v2_tracking_url', null, $number, $carrier, $order),
            'status'  => (string) $order->get_meta(self::SHIPGO_STATUS),
        ];
    }

    /* ── GET /orders/{id}/live-tracking ────────────── */

    /**
     * Where the courier is, right now.
     *
     * The store holds only the last status sapconnect pushed on a phase change,
     * which is enough for a badge but not for a dot on a map. So this proxies
     * sapconnect, which in turn re-fetches Mrsool when its own row has gone
     * stale — and the answer is cached for a few seconds per order so a customer
     * staring at the map cannot turn one courier into a stream of API calls.
     *
     * Returns `null` data (200) rather than an error when there is no courier:
     * the app simply hides the panel, which is also the right answer for every
     * non-express order.
     */
    public function live_tracking(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->owned_order($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }

        // Orders that can never have a courier are answered here, without a
        // round trip. Everything else has to ask, INCLUDING an express order
        // with no courier yet: the branch may request one while the customer is
        // looking at the screen, and gating on the meta would mean the panel
        // could only ever appear after pickup.
        if (!$this->could_have_courier($order)) {
            return Zooboxi_V2_Bootstrap::ok(null);
        }

        $tracking = $this->courier_for($order);

        // We could not ask. Say so instead of answering "no courier" — the app
        // must keep polling, because the one moment this is most likely to time
        // out is the moment the delivery completes.
        if ($tracking === false) {
            return Zooboxi_V2_Bootstrap::fail(
                'tracking_unavailable',
                __('تعذّر تحديث موقع المندوب الآن', 'zooboxi'),
                'Could not refresh the courier position right now.',
                503
            );
        }

        return Zooboxi_V2_Bootstrap::ok($tracking);
    }

    /**
     * The courier for one order, through a short per-order cache.
     *
     * @return array|null|false — the payload, "no courier", or "could not ask".
     */
    private function courier_for(\WC_Order $order)
    {
        $order_id  = $order->get_id();
        $cache_key = 'zb_mrsool_live_' . $order_id;
        $cached    = get_transient($cache_key);

        if (is_array($cached)) {
            return $cached['data'];
        }

        if (!class_exists('Zooboxi_Sync_Engine')) {
            return null;
        }

        $engine   = new Zooboxi_Sync_Engine();
        $tracking = $engine->fetch_mrsool_tracking($order_id);

        if ($tracking === false) {
            return false;
        }

        // A delivered courier never moves again, so its payload can rest much
        // longer than a live one. "No courier yet" rests briefly: the branch
        // may be requesting one right now.
        $ttl = match (true) {
            $tracking === null => 15,
            in_array($tracking['phase'] ?? '', ['delivered', 'failed'], true) => 600,
            default => 10,
        };
        set_transient($cache_key, ['data' => $tracking], $ttl);

        return $tracking;
    }

    /* ── GET /orders/active ────────────────────────── */

    /**
     * The one order the customer is currently waiting on, if there is one.
     *
     * This is what the live bar above the tab bar is built from, so it answers
     * in a single round trip: the order AND its courier. A customer browsing
     * the shop should never have to go looking for the thing they just bought.
     *
     * Express only, and deliberately so. A shipment arriving in four days is
     * not something to hover over the shop for; an order arriving within the
     * hour is the only one worth the screen space.
     */
    public function active(\WP_REST_Request $request): \WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Zooboxi_V2_Bootstrap::unauthorized();
        }

        $orders = wc_get_orders([
            'customer_id' => $user_id,
            'limit'       => 10,
            'orderby'     => 'date',
            'order'       => 'DESC',
            'status'      => ['processing', 'zb-ready', 'zb-out-for-delivery'],
            // Filter in the query, not in PHP: five newer non-express orders
            // would otherwise push the express one out of the window.
            'meta_query'  => [[
                'key'   => '_zooboxi_delivery_type',
                'value' => 'express',
            ]],
            // An express order promises two hours. One that is still sitting in
            // `processing` a week later was abandoned somewhere, and pinning the
            // bar to a customer's screen forever is worse than showing nothing.
            'date_created' => '>' . (time() - DAY_IN_SECONDS),
        ]);

        $best = null;
        foreach ((array) $orders as $order) {
            if (!$order instanceof \WC_Order) {
                continue;
            }
            // Newest is the wrong question. A courier five minutes from the door
            // matters more than a box someone started packing a moment ago, so a
            // moving order outranks a waiting one and date only breaks ties.
            if ($best === null || self::urgency($order) > self::urgency($best)) {
                $best = $order;
            }
        }

        if ($best === null) {
            return Zooboxi_V2_Bootstrap::ok(null);
        }

        $courier = $this->courier_for($best);
        $dto     = $this->list_dto($best);

        // The order key is the pay/receipt capability token. The bar never uses
        // it, and this is the most frequently polled payload in the app.
        unset($dto['order_key']);

        return Zooboxi_V2_Bootstrap::ok([
            'order' => $dto,
            // A courier we could not reach is reported as absent here: the bar
            // still has a real order status to show, and losing the whole bar
            // over a slow proxy would be the worse trade.
            'tracking' => $courier === false ? null : $courier,
        ]);
    }

    /** How much this order deserves the bar. Higher wins; date breaks ties. */
    private static function urgency(\WC_Order $order): int
    {
        $rank = match ($order->get_status()) {
            'zb-out-for-delivery' => 3,
            'zb-ready'            => 2,
            default               => 1,
        };

        $created = $order->get_date_created();

        return $rank * 10000000000 + ($created ? $created->getTimestamp() : 0);
    }

    /**
     * Could this order have a Mrsool courier at all?
     *
     * True once one has been requested (the meta is there), and true for any
     * express order that has not finished — that is the window in which the
     * branch can still call one.
     */
    private function could_have_courier(\WC_Order $order): bool
    {
        if ((string) $order->get_meta(self::MRSOOL_ORDER_ID) !== '') {
            return true;
        }

        if ((string) $order->get_meta('_zooboxi_delivery_type') !== 'express') {
            return false;
        }

        return !in_array($order->get_status(), ['cancelled', 'refunded', 'failed', 'pending'], true);
    }

    /* ── Helpers ───────────────────────────────────── */

    private function owned_order(\WP_REST_Request $request): ?\WC_Order
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return null;
        }
        $order = wc_get_order(absint($request->get_param('id')));
        if (!($order instanceof \WC_Order)) {
            return null;
        }
        return ((int) $order->get_customer_id() === $user_id) ? $order : null;
    }
}
