<?php
/**
 * Zooboxi_V2_Checkout_Controller — review, place, and pay for an order.
 *
 * The order is created by WooCommerce's own WC_Checkout::create_order() and then the
 * CLASSIC `woocommerce_checkout_order_processed` action is fired by hand, so everything
 * the website's checkout triggers still runs untouched: Zooboxi_Plugin::on_order_created
 * stamps the delivery metadata and Zooboxi_Sync_Engine::push_order() mirrors the order to
 * sapconnect → the staff app → SAP. The app is just another till, not a second pipeline.
 *
 * The delivery ADDRESS wins over the browsing location: its coordinates are seeded into
 * the cookie jar BEFORE the cart is loaded, so stock filtering, the reachable-quantity
 * cap and the shipping methods all resolve against the place the order is going.
 */
if (!defined('ABSPATH')) {
    exit;
}

class Zooboxi_V2_Checkout_Controller
{
    /** The MyFatoorah gateway id installed on this store (verified in production). */
    public const GATEWAY_MYFATOORAH = 'myfatoorah_v2';
    public const GATEWAY_COD        = 'cod';

    /** Delivery tier → the shipping method that serves it. */
    private const TIER_METHOD = [
        Zooboxi_Delivery_Engine::TYPE_EXPRESS  => 'zooboxi_express',
        Zooboxi_Delivery_Engine::TYPE_STANDARD => 'zooboxi_standard',
        Zooboxi_Delivery_Engine::TYPE_SHIPPING => 'zooboxi_shipping',
        Zooboxi_Delivery_Engine::TYPE_PICKUP   => 'zooboxi_pickup',
    ];

    public function register_routes(): void
    {
        Zooboxi_V2_Bootstrap::route('/checkout', 'GET', [$this, 'review']);
        Zooboxi_V2_Bootstrap::route('/checkout', 'POST', [$this, 'place']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)/pay', 'POST', [$this, 'pay']);
        Zooboxi_V2_Bootstrap::route('/orders/(?P<id>\d+)/status', 'GET', [$this, 'status']);
        Zooboxi_V2_Bootstrap::route('/payments/config', 'POST', [$this, 'payment_config']);
        Zooboxi_V2_Bootstrap::route('/payments/verify', 'POST', [$this, 'payment_verify']);
    }

    /* ══════════════════════════════════════════════════════════════
       Native MyFatoorah SDK support
       ══════════════════════════════════════════════════════════════ */

    /** The gateway's own saved settings (same option the web checkout runs on). */
    private function myfatoorah_settings(): array
    {
        $settings = get_option('woocommerce_myfatoorah_v2_settings', []);
        return is_array($settings) ? $settings : [];
    }

    private function myfatoorah_api_base(array $settings): string
    {
        if (($settings['testMode'] ?? 'no') === 'yes') {
            return 'https://apitest.myfatoorah.com';
        }
        // Saudi merchants live on the KSA cluster.
        return ($settings['countryMode'] ?? 'SAU') === 'SAU'
            ? 'https://api-sa.myfatoorah.com'
            : 'https://api.myfatoorah.com';
    }

    /**
     * POST /payments/config {order_id, key}
     *
     * Hands the app what the native MyFatoorah SDK needs for THIS order. Gated
     * on a real, unpaid order (order_key or ownership) so the credential is
     * only ever released against a live payment attempt — it is never compiled
     * into the binary.
     */
    public function payment_config(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->order_by_key($request, 'order_id');
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }
        if ($order->is_paid()) {
            return Zooboxi_V2_Bootstrap::fail('already_paid', __('تم دفع هذا الطلب', 'zooboxi'), 'This order is already paid.', 409);
        }

        $settings = $this->myfatoorah_settings();
        $token    = (string) ($settings['apiKey'] ?? '');
        if ($token === '' || ($settings['enabled'] ?? 'no') !== 'yes') {
            return Zooboxi_V2_Bootstrap::fail('gateway_unavailable', __('بوابة الدفع غير متاحة حالياً', 'zooboxi'), 'The payment gateway is unavailable.', 503);
        }

        return Zooboxi_V2_Bootstrap::ok([
            'gateway'   => 'myfatoorah',
            'token'     => $token,
            'country'   => (string) ($settings['countryMode'] ?? 'SAU'),
            'env'       => ($settings['testMode'] ?? 'no') === 'yes' ? 'test' : 'live',
            'order_id'  => $order->get_id(),
            'amount'    => (float) $order->get_total(),
            'currency'  => $order->get_currency() ?: 'SAR',
            'reference' => (string) $order->get_id(),
            // Embedded Apple Pay: the button is MyFatoorah's own Apple Pay
            // page in a WKWebView under THEIR merchant identity — no Apple
            // merchant id, certificate or entitlement exists on our side
            // (their support confirmed, 2026-08-26; the account carries
            // "Apple Pay (mada)", method id 13). This flag is the only
            // switch — no app release needed on the day.
            'apple_pay'   => get_option('zooboxi_apple_pay_native', 'no') === 'yes',
            'merchant_id' => (string) get_option('zooboxi_apple_merchant_id', 'merchant.com.zooboxi.store'),
        ]);
    }

    /**
     * POST /payments/verify {order_id, key, invoice_id}
     *
     * The server-authoritative confirmation: the app NEVER decides money moved.
     * We ask MyFatoorah for the invoice, check it is Paid, belongs to this
     * order and matches its total, and only then mark the order paid.
     */
    public function payment_verify(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->order_by_key($request, 'order_id');
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }

        if ($order->is_paid()) {
            return Zooboxi_V2_Bootstrap::ok(['is_paid' => true, 'status' => $order->get_status()]);
        }

        $invoice_id = sanitize_text_field((string) $request->get_param('invoice_id'));
        if ($invoice_id === '' || !preg_match('/^\d{1,20}$/', $invoice_id)) {
            return Zooboxi_V2_Bootstrap::fail('invoice_required', __('بيانات الدفع غير مكتملة', 'zooboxi'), 'A MyFatoorah invoice id is required.', 422);
        }

        $settings = $this->myfatoorah_settings();
        $token    = (string) ($settings['apiKey'] ?? '');
        if ($token === '') {
            return Zooboxi_V2_Bootstrap::fail('gateway_unavailable', __('بوابة الدفع غير متاحة حالياً', 'zooboxi'), 'The payment gateway is unavailable.', 503);
        }

        $response = wp_remote_post($this->myfatoorah_api_base($settings) . '/v2/GetPaymentStatus', [
            'headers' => [
                'Authorization' => 'Bearer ' . $token,
                'Content-Type'  => 'application/json',
            ],
            'body'    => wp_json_encode(['Key' => $invoice_id, 'KeyType' => 'InvoiceId']),
            'timeout' => 15,
        ]);
        if (is_wp_error($response)) {
            return Zooboxi_V2_Bootstrap::fail('verify_failed', __('تعذّر التحقق من الدفع. حاول بعد لحظات', 'zooboxi'), 'Could not verify the payment.', 502);
        }

        $body = json_decode(wp_remote_retrieve_body($response), true);
        $data = is_array($body) && isset($body['Data']) && is_array($body['Data']) ? $body['Data'] : null;
        if ($data === null || empty($body['IsSuccess'])) {
            return Zooboxi_V2_Bootstrap::fail('verify_failed', __('تعذّر التحقق من الدفع. حاول بعد لحظات', 'zooboxi'), 'Could not verify the payment.', 502);
        }

        $status    = (string) ($data['InvoiceStatus'] ?? '');
        $reference = (string) ($data['CustomerReference'] ?? '');
        $value     = (float) ($data['InvoiceValue'] ?? 0);

        if ($reference !== (string) $order->get_id()) {
            error_log('[Zooboxi v2] payment_verify: invoice ' . $invoice_id . ' reference mismatch (' . $reference . ' vs order ' . $order->get_id() . ')');
            return Zooboxi_V2_Bootstrap::fail('verify_mismatch', __('بيانات الدفع لا تخص هذا الطلب', 'zooboxi'), 'That payment does not belong to this order.', 409);
        }

        if ($status !== 'Paid') {
            return Zooboxi_V2_Bootstrap::ok(['is_paid' => false, 'status' => $status !== '' ? strtolower($status) : 'pending']);
        }

        if (abs($value - (float) $order->get_total()) > 0.05) {
            error_log('[Zooboxi v2] payment_verify: invoice ' . $invoice_id . ' amount mismatch (' . $value . ' vs ' . $order->get_total() . ')');
            return Zooboxi_V2_Bootstrap::fail('verify_mismatch', __('مبلغ الدفع لا يطابق الطلب', 'zooboxi'), 'The paid amount does not match the order.', 409);
        }

        // Reference, status and amount all line up — settle the order. The
        // transaction id lets refunds in Woo admin find the MyFatoorah invoice.
        $order->add_order_note(sprintf('MyFatoorah SDK payment verified — invoice %s', $invoice_id));
        $order->payment_complete($invoice_id);

        return Zooboxi_V2_Bootstrap::ok(['is_paid' => true, 'status' => $order->get_status()]);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /checkout — the review screen
       ══════════════════════════════════════════════════════════════ */

    public function review(\WP_REST_Request $request): \WP_REST_Response
    {
        if (!Zooboxi_V2_Cart_Controller::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::fail('cart_unavailable', __('السلة غير متاحة حالياً', 'zooboxi'), 'The cart is unavailable right now.', 503);
        }
        if (WC()->cart->is_empty()) {
            return Zooboxi_V2_Bootstrap::fail('cart_empty', __('سلتك فارغة', 'zooboxi'), 'Your cart is empty.', 409);
        }

        $this->prepare_customer_from_location();
        $this->auto_choose_shipping();

        $cart = Zooboxi_V2_Cart_Controller::cart_dto();

        return Zooboxi_V2_Bootstrap::ok([
            'shipments'       => $cart['shipments'],
            'items'           => $cart['items'],
            'totals'          => $cart['totals'],
            'free_shipping'   => $cart['free_shipping'],
            'coupons'         => $cart['coupons'],
            'notices'         => $cart['notices'],
            'payment_methods' => $this->payment_methods(),
            'addresses'       => Zooboxi_V2_Account_Controller::get_addresses(get_current_user_id()),
            'promise'         => $this->promise_recap($cart['shipments']),
        ]);
    }

    /** Only the gateways WooCommerce reports as available, allowlisted + labelled. */
    private function payment_methods(): array
    {
        $available = WC()->payment_gateways() ? WC()->payment_gateways()->get_available_payment_gateways() : [];

        $labels = [
            self::GATEWAY_COD => [
                'id'     => 'cod',
                'label'  => __('الدفع عند الاستلام', 'zooboxi'),
                'label_en' => 'Cash on delivery',
                'sub'    => __('ادفع نقداً أو بالشبكة عند وصول طلبك', 'zooboxi'),
            ],
            self::GATEWAY_MYFATOORAH => [
                'id'     => 'myfatoorah',
                'label'  => __('البطاقات ومدى و Apple Pay', 'zooboxi'),
                'label_en' => 'Cards, mada & Apple Pay',
                'sub'    => __('دفع آمن عبر ماي فاتورة', 'zooboxi'),
            ],
        ];

        $out = [];
        foreach ($labels as $gateway_id => $meta) {
            if (!isset($available[$gateway_id])) {
                continue;
            }
            $out[] = [
                'id'    => $meta['id'],
                'label' => Zooboxi_V2_Bootstrap::pick($meta['label'], $meta['label_en']),
                'sub'   => $meta['sub'],
            ];
        }
        return $out;
    }

    private function promise_recap(array $shipments): array
    {
        $lines = [];
        foreach ($shipments as $s) {
            $lines[] = [
                'tier'  => (string) ($s['tier'] ?? ''),
                'label' => trim(((string) ($s['icon'] ?? '')) . ' ' . ((string) ($s['label'] ?? ''))),
                'when'  => trim(((string) ($s['date_label'] ?? '')) . ' — ' . ((string) ($s['relative_label'] ?? ''))),
            ];
        }
        return [
            'is_split' => count($shipments) > 1,
            'lines'    => $lines,
        ];
    }

    /* ══════════════════════════════════════════════════════════════
       POST /checkout — place the order
       ══════════════════════════════════════════════════════════════ */

    public function place(\WP_REST_Request $request): \WP_REST_Response
    {
        $address = $this->resolve_address($request);
        if (is_string($address)) {
            return Zooboxi_V2_Bootstrap::fail($address, $this->address_error_ar($address), $this->address_error_en($address), 422);
        }

        $payment = sanitize_key((string) $request->get_param('payment_method'));
        $gateway_id = ($payment === 'myfatoorah' || $payment === self::GATEWAY_MYFATOORAH)
            ? self::GATEWAY_MYFATOORAH
            : self::GATEWAY_COD;

        // The DELIVERY address defines the fulfilment location — seed it before the cart
        // boots so the stock filter, the reachable cap and the shipping methods all agree.
        $_COOKIE['zooboxi_lat']  = (string) $address['lat'];
        $_COOKIE['zooboxi_lng']  = (string) $address['lng'];
        $_COOKIE['zooboxi_city'] = $address['city'];
        if ($address['district'] !== '') {
            $_COOKIE['zooboxi_district'] = $address['district'];
        }

        if (!Zooboxi_V2_Cart_Controller::ensure_cart($request)) {
            return Zooboxi_V2_Bootstrap::fail('cart_unavailable', __('السلة غير متاحة حالياً', 'zooboxi'), 'The cart is unavailable right now.', 503);
        }
        if (!Zooboxi_V2_Cart_Controller::session_ok()) {
            return Zooboxi_V2_Bootstrap::fail('cart_session_unavailable', __('تعذّر حفظ سلتك. حاول لاحقاً', 'zooboxi'), 'The cart session could not be established.', 503);
        }
        if (WC()->cart->is_empty()) {
            return Zooboxi_V2_Bootstrap::fail('cart_empty', __('سلتك فارغة', 'zooboxi'), 'Your cart is empty.', 409);
        }

        // Did loading the cart at the DELIVERY location change anything (the reachable
        // cap trimming a line)? Then the customer must re-confirm before we take money.
        if (function_exists('wc_get_notices') && !empty(wc_get_notices())) {
            return Zooboxi_V2_Bootstrap::fail(
                'cart_changed',
                __('تغيّرت سلتك بحسب المتاح في عنوان التوصيل — راجعها ثم أكمل', 'zooboxi'),
                'Your cart changed based on what is available at the delivery address. Please review it.',
                409,
                ['cart' => Zooboxi_V2_Cart_Controller::cart_dto()]
            );
        }

        $gateways = WC()->payment_gateways() ? WC()->payment_gateways()->get_available_payment_gateways() : [];
        if (!isset($gateways[$gateway_id])) {
            return Zooboxi_V2_Bootstrap::fail('gateway_unavailable', __('طريقة الدفع غير متاحة', 'zooboxi'), 'That payment method is unavailable.', 409);
        }

        $this->apply_address_to_customer($address);
        $chosen = $this->auto_choose_shipping();

        $notes = sanitize_textarea_field((string) $request->get_param('notes'));

        $posted = [
            'payment_method'       => $gateway_id,
            'billing_first_name'   => $address['name'],
            'billing_last_name'    => '',
            'billing_phone'        => $address['phone'],
            'billing_email'        => $this->billing_email($address),
            'billing_country'      => 'SA',
            'billing_city'         => $address['city'],
            'billing_address_1'    => $address['address_line'],
            'billing_address_2'    => $address['district'],
            'billing_postcode'     => '',
            'billing_state'        => '',
            'shipping_first_name'  => $address['name'],
            'shipping_last_name'   => '',
            'shipping_country'     => 'SA',
            'shipping_city'        => $address['city'],
            'shipping_address_1'   => $address['address_line'],
            'shipping_address_2'   => $address['district'],
            'shipping_postcode'    => '',
            'shipping_state'       => '',
            'shipping_phone'       => $address['phone'],
            'order_comments'       => $notes,
        ];

        try {
            $order_id = WC()->checkout()->create_order($posted);
        } catch (\Throwable $e) {
            error_log('[Zooboxi v2] create_order failed: ' . $e->getMessage());
            $order_id = new \WP_Error('zb_create_order_failed', $e->getMessage());
        }

        if (is_wp_error($order_id) || !$order_id) {
            return Zooboxi_V2_Bootstrap::fail(
                'order_failed',
                __('تعذّر إنشاء الطلب. حاول مرة أخرى', 'zooboxi'),
                'The order could not be created. Please try again.',
                500
            );
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Zooboxi_V2_Bootstrap::fail('order_failed', __('تعذّر إنشاء الطلب. حاول مرة أخرى', 'zooboxi'), 'The order could not be created.', 500);
        }

        // The precise map pin the SAP mirror prefers, plus the app's own provenance.
        $order->update_meta_data('_zooboxi_checkout_lat', (string) $address['lat']);
        $order->update_meta_data('_zooboxi_checkout_lng', (string) $address['lng']);
        $order->update_meta_data('_zooboxi_source', 'app');
        $order->save();

        // Save the address book entry when asked.
        if (!empty($address['save']) && get_current_user_id()) {
            Zooboxi_V2_Account_Controller::save_address(get_current_user_id(), $address);
        }

        // Fire the CLASSIC hook so on_order_created + push_order run exactly as on the web.
        do_action('woocommerce_checkout_order_processed', (int) $order_id, $posted, $order);

        $payment_required = ($gateway_id === self::GATEWAY_MYFATOORAH);

        if (!$payment_required) {
            $order->update_status('processing', __('طلب عبر تطبيق زوبوكسي — الدفع عند الاستلام', 'zooboxi'));
        }

        WC()->cart->empty_cart();

        return Zooboxi_V2_Bootstrap::ok([
            'order_id'         => (int) $order_id,
            'order_number'     => (string) $order->get_order_number(),
            'order_key'        => (string) $order->get_order_key(),
            'total'            => (float) $order->get_total(),
            'currency'         => 'SAR',
            'status'           => (string) $order->get_status(),
            'payment_method'   => $gateway_id === self::GATEWAY_MYFATOORAH ? 'myfatoorah' : 'cod',
            'payment_required' => $payment_required,
            'shipping_chosen'  => $chosen,
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       POST /orders/{id}/pay
       ══════════════════════════════════════════════════════════════ */

    public function pay(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->order_by_key($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }
        if ($order->is_paid()) {
            return Zooboxi_V2_Bootstrap::fail('already_paid', __('تم دفع هذا الطلب', 'zooboxi'), 'This order is already paid.', 409);
        }

        // The MyFatoorah plugin's process_payment() reaches for WC()->session /
        // WC()->cart, which a bare REST request never booted — that null is the
        // "Call to a member function get() on null" its logs showed. Boot them.
        Zooboxi_V2_Cart_Controller::ensure_cart($request);

        $gateways = WC()->payment_gateways() ? WC()->payment_gateways()->get_available_payment_gateways() : [];
        $gateway  = $gateways[self::GATEWAY_MYFATOORAH] ?? null;

        if (!$gateway || !is_callable([$gateway, 'process_payment'])) {
            return Zooboxi_V2_Bootstrap::fail(
                'gateway_unavailable',
                __('بوابة الدفع غير متاحة حالياً', 'zooboxi'),
                'The payment gateway is unavailable right now.',
                503
            );
        }

        $order->set_payment_method($gateway);
        $order->save();

        try {
            $result = $gateway->process_payment($order->get_id());
        } catch (\Throwable $e) {
            error_log('[Zooboxi v2] process_payment failed: ' . $e->getMessage());
            $result = null;
        }

        $redirect = is_array($result) ? (string) ($result['redirect'] ?? '') : '';
        if ($redirect === '') {
            return Zooboxi_V2_Bootstrap::fail(
                'gateway_unavailable',
                __('تعذّر بدء عملية الدفع. حاول مرة أخرى', 'zooboxi'),
                'The payment session could not be started. Please try again.',
                502
            );
        }

        return Zooboxi_V2_Bootstrap::ok([
            'payment_url' => esc_url_raw($redirect),
            'order_id'    => $order->get_id(),
        ]);
    }

    /* ══════════════════════════════════════════════════════════════
       GET /orders/{id}/status  (order_key gated, cheap poll target)
       ══════════════════════════════════════════════════════════════ */

    public function status(\WP_REST_Request $request): \WP_REST_Response
    {
        $order = $this->order_by_key($request);
        if ($order === null) {
            return Zooboxi_V2_Bootstrap::fail('order_not_found', __('الطلب غير موجود', 'zooboxi'), 'Order not found.', 404);
        }

        return Zooboxi_V2_Bootstrap::ok([
            'order_id' => $order->get_id(),
            'status'   => (string) $order->get_status(),
            'is_paid'  => (bool) $order->is_paid(),
        ]);
    }

    /** Order lookup gated on the order key (or ownership for a signed-in customer). */
    private function order_by_key(\WP_REST_Request $request, string $id_param = 'id'): ?\WC_Order
    {
        $order = wc_get_order(absint($request->get_param($id_param)));
        if (!($order instanceof \WC_Order)) {
            return null;
        }

        $key = (string) $request->get_param('key');
        if ($key !== '' && hash_equals((string) $order->get_order_key(), $key)) {
            return $order;
        }

        $user_id = get_current_user_id();
        if ($user_id && (int) $order->get_customer_id() === $user_id) {
            return $order;
        }

        return null;
    }

    /* ══════════════════════════════════════════════════════════════
       SHIPPING / CUSTOMER
       ══════════════════════════════════════════════════════════════ */

    /**
     * Pick one shipping rate PER PACKAGE by its delivery tier. With smart shipments on
     * there can be several packages (express + next-day + national) in one order, and
     * each must get its own matching method.
     *
     * @return array<int,string> package index → chosen rate id
     */
    private function auto_choose_shipping(): array
    {
        if (!WC()->cart) {
            return [];
        }

        WC()->cart->calculate_totals();

        $packages = WC()->shipping() ? WC()->shipping()->get_packages() : [];
        $chosen   = [];

        foreach ($packages as $i => $package) {
            $rates = is_array($package['rates'] ?? null) ? $package['rates'] : [];
            if (empty($rates)) {
                continue;
            }

            $tier      = (string) ($package['zooboxi_tier'] ?? '');
            $preferred = $tier !== '' ? (self::TIER_METHOD[$tier] ?? '') : '';

            $pick = '';
            if ($preferred !== '') {
                foreach ($rates as $rate_id => $rate) {
                    if ($rate_id === $preferred || $rate->get_method_id() === $preferred) {
                        $pick = (string) $rate_id;
                        break;
                    }
                }
            }
            if ($pick === '') {
                // No tier hint (single un-split package) → fastest available wins.
                foreach (['zooboxi_express', 'zooboxi_standard', 'zooboxi_shipping'] as $fallback) {
                    foreach ($rates as $rate_id => $rate) {
                        if ($rate_id === $fallback || $rate->get_method_id() === $fallback) {
                            $pick = (string) $rate_id;
                            break 2;
                        }
                    }
                }
            }
            if ($pick === '') {
                $pick = (string) array_key_first($rates);
            }

            $chosen[$i] = $pick;
        }

        if (!empty($chosen) && WC()->session) {
            WC()->session->set('chosen_shipping_methods', $chosen);
            WC()->cart->calculate_totals();
        }

        return $chosen;
    }

    /** Make sure WooCommerce's customer object has a destination before totals run. */
    private function prepare_customer_from_location(): void
    {
        if (!WC()->customer) {
            return;
        }
        $city = Zooboxi_V2_Bootstrap::city();

        WC()->customer->set_billing_country('SA');
        WC()->customer->set_shipping_country('SA');
        if ($city !== '') {
            WC()->customer->set_billing_city($city);
            WC()->customer->set_shipping_city($city);
        }
    }

    private function apply_address_to_customer(array $address): void
    {
        Zooboxi_V2_Bootstrap::mirror_location_to_session();

        if (WC()->session) {
            WC()->session->set('zooboxi_customer_lat', (float) $address['lat']);
            WC()->session->set('zooboxi_customer_lng', (float) $address['lng']);
            WC()->session->set('zooboxi_customer_city', $address['city']);
            WC()->session->set('zooboxi_customer_district', $address['district']);

            // The tier/warehouse the order will be fulfilled from — read back by
            // Zooboxi_Plugin::on_order_created and forwarded to sapconnect.
            $options = Zooboxi_Delivery_Engine::detect_options(
                (float) $address['lat'],
                (float) $address['lng'],
                [],
                $address['city'] !== '' ? $address['city'] : null
            );
            $best = $options['express'] ?? $options['standard'] ?? $options['shipping'] ?? null;
            if ($best) {
                WC()->session->set('zooboxi_warehouse_code', (string) ($best['warehouse_code'] ?? ''));
                WC()->session->set('zooboxi_delivery_type', (string) ($best['delivery_type'] ?? ''));
            }
        }

        if (!WC()->customer) {
            return;
        }

        $customer = WC()->customer;
        $customer->set_billing_first_name($address['name']);
        $customer->set_billing_phone($address['phone']);
        $customer->set_billing_country('SA');
        $customer->set_billing_city($address['city']);
        $customer->set_billing_address_1($address['address_line']);
        $customer->set_billing_address_2($address['district']);
        $customer->set_shipping_first_name($address['name']);
        $customer->set_shipping_country('SA');
        $customer->set_shipping_city($address['city']);
        $customer->set_shipping_address_1($address['address_line']);
        $customer->set_shipping_address_2($address['district']);
    }

    private function billing_email(array $address): string
    {
        $user_id = get_current_user_id();
        if ($user_id) {
            $user = get_userdata($user_id);
            if ($user && is_email($user->user_email)) {
                return $user->user_email;
            }
        }
        if (!empty($address['email']) && is_email($address['email'])) {
            return (string) $address['email'];
        }
        // WooCommerce requires an address for coupon holds and receipts; the OTP flow
        // already parks new accounts on this placeholder domain.
        $digits = preg_replace('/[^0-9]/', '', (string) $address['phone']);
        return 'zb_' . ($digits !== '' ? $digits : 'guest') . '@zooboxi.local';
    }

    /* ══════════════════════════════════════════════════════════════
       ADDRESS RESOLUTION
       ══════════════════════════════════════════════════════════════ */

    /**
     * @return array|string the normalised address, or an error code string.
     */
    private function resolve_address(\WP_REST_Request $request)
    {
        $address_id = sanitize_text_field((string) $request->get_param('address_id'));

        if ($address_id !== '') {
            $user_id = get_current_user_id();
            if (!$user_id) {
                return 'address_requires_login';
            }
            $saved = Zooboxi_V2_Account_Controller::find_address($user_id, $address_id);
            if (!$saved) {
                return 'address_not_found';
            }
            $raw = $saved;
        } else {
            $raw = $request->get_param('address');
            if (!is_array($raw)) {
                return 'address_required';
            }
        }

        $address = [
            'id'           => sanitize_text_field((string) ($raw['id'] ?? '')),
            'label'        => sanitize_text_field((string) ($raw['label'] ?? '')),
            'name'         => sanitize_text_field((string) ($raw['name'] ?? '')),
            'phone'        => sanitize_text_field((string) ($raw['phone'] ?? '')),
            'city'         => sanitize_text_field((string) ($raw['city'] ?? '')),
            'district'     => sanitize_text_field((string) ($raw['district'] ?? '')),
            'address_line' => sanitize_text_field((string) ($raw['address_line'] ?? '')),
            'email'        => sanitize_email((string) ($raw['email'] ?? '')),
            'lat'          => (float) ($raw['lat'] ?? 0),
            'lng'          => (float) ($raw['lng'] ?? 0),
            'save'         => (bool) $request->get_param('save') || !empty($raw['save']),
        ];

        if ($address['name'] === '') {
            return 'name_required';
        }
        if (Zooboxi_OTP_Auth::format_saudi_phone($address['phone']) === '') {
            return 'phone_invalid';
        }
        if (!$address['lat'] || !$address['lng'] || abs($address['lat']) > 90 || abs($address['lng']) > 180) {
            return 'coordinates_required';
        }
        if ($address['address_line'] === '') {
            return 'address_line_required';
        }
        if ($address['city'] === '') {
            $geo = Zooboxi_Location_Detector::reverse_geocode($address['lat'], $address['lng']);
            $address['city'] = (string) ($geo['city'] ?? '');
            if ($address['district'] === '') {
                $address['district'] = (string) ($geo['district'] ?? '');
            }
        }
        if ($address['city'] === '') {
            return 'city_required';
        }

        return $address;
    }

    private function address_error_ar(string $code): string
    {
        switch ($code) {
            case 'address_requires_login':
                return __('يرجى تسجيل الدخول لاستخدام عنوان محفوظ', 'zooboxi');
            case 'address_not_found':
                return __('العنوان غير موجود', 'zooboxi');
            case 'name_required':
                return __('الاسم مطلوب', 'zooboxi');
            case 'phone_invalid':
                return __('يرجى إدخال رقم جوال سعودي صالح', 'zooboxi');
            case 'coordinates_required':
                return __('حدّد موقع التوصيل على الخريطة', 'zooboxi');
            case 'address_line_required':
                return __('تفاصيل العنوان مطلوبة', 'zooboxi');
            case 'city_required':
                return __('المدينة مطلوبة', 'zooboxi');
            default:
                return __('بيانات العنوان غير مكتملة', 'zooboxi');
        }
    }

    private function address_error_en(string $code): string
    {
        switch ($code) {
            case 'address_requires_login':
                return 'Sign in to use a saved address.';
            case 'address_not_found':
                return 'That saved address no longer exists.';
            case 'name_required':
                return 'A recipient name is required.';
            case 'phone_invalid':
                return 'A valid Saudi mobile number is required.';
            case 'coordinates_required':
                return 'Pick the delivery point on the map.';
            case 'address_line_required':
                return 'Address details are required.';
            case 'city_required':
                return 'A city is required.';
            default:
                return 'The address is incomplete.';
        }
    }
}
