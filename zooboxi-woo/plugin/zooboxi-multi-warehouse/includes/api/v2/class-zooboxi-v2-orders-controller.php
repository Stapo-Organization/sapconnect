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

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/orders', 'GET', [$this, 'index']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)', 'GET', [$this, 'show']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)/reorder', 'POST', [$this, 'reorder']);
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
            'can_reorder'   => in_array($status, ['completed', 'processing', 'zb-ready', 'cancelled', 'refunded'], true),
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
     * placed → paid → preparing → ready → completed, each with the moment it happened
     * (from the `_zb_status_{status}_at` stamps) and whether it is done.
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
        $completed_at = $stamp($order, 'completed');
        if ($completed_at === null && $order->get_date_completed()) {
            $completed_at = $order->get_date_completed()->date(DATE_ATOM);
        }

        $rank = ['pending' => 0, 'failed' => 0, 'on-hold' => 1, 'processing' => 2, 'zb-ready' => 3, 'completed' => 4];
        $now  = $rank[$status] ?? 0;

        return [
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
            [
                'key'   => 'completed',
                'label' => Zooboxi_V2_Bootstrap::pick(__('تم التسليم', 'zooboxi'), 'Delivered'),
                'at'    => $completed_at,
                'done'  => $now >= 4,
            ],
        ];
    }

    /** ShipGo tracking, when the fulfilment connector has stamped it. */
    private function tracking(\WC_Order $order): ?array
    {
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
