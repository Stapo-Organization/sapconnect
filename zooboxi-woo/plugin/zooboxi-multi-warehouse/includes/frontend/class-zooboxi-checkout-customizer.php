<?php
/**
 * Checkout Customizer — Smart checkout with embedded Google Maps,
 * simplified Arabic fields, auto-fill from OTP profile, and
 * dynamic shipping recalculation on map move.
 */
class Zooboxi_Checkout_Customizer
{
    public function __construct()
    {
        // Save delivery meta to order
        add_action('woocommerce_checkout_update_order_meta', [$this, 'save_delivery_meta']);

        // Delivery summary before order review
        add_action('woocommerce_checkout_before_order_review', [$this, 'render_delivery_summary']);

        // Customize checkout fields
        add_filter('woocommerce_checkout_fields', [$this, 'customize_fields'], 999);
        add_filter('woocommerce_default_address_fields', [$this, 'translate_fields'], 999);

        // Inject map into checkout
        add_action('woocommerce_before_checkout_billing_form', [$this, 'render_checkout_map'], 5);

        // Pre-fill from user profile
        add_filter('woocommerce_checkout_get_value', [$this, 'prefill_values'], 10, 2);

        // AJAX for dynamic location update during checkout
        add_action('wp_ajax_zooboxi_update_checkout_location', [self::class, 'ajax_update_checkout_location']);
        add_action('wp_ajax_nopriv_zooboxi_update_checkout_location', [self::class, 'ajax_update_checkout_location']);

        // Enqueue checkout map JS
        add_action('wp_enqueue_scripts', [$this, 'enqueue_checkout_assets']);

        // Save GPS coordinates from checkout map to order
        add_action('woocommerce_checkout_update_order_meta', [$this, 'save_map_meta'], 20);
    }

    /* ─────────────────────────────────────────────
     * Customize Checkout Fields
     * ───────────────────────────────────────────── */

    public function customize_fields(array $fields): array
    {
        // ── Remove unnecessary fields ──
        unset(
            $fields['billing']['billing_company'],
            $fields['billing']['billing_postcode'],
            $fields['billing']['billing_state'],
            $fields['billing']['billing_address_2']
        );

        // ── Simplify billing_country (hidden, always SA) ──
        $fields['billing']['billing_country'] = [
            'type'     => 'hidden',
            'default'  => 'SA',
            'required' => true,
            'priority' => 1,
        ];

        // ── Reorder & style fields ──
        if (isset($fields['billing']['billing_first_name'])) {
            $fields['billing']['billing_first_name']['label']    = 'الاسم الأول';
            $fields['billing']['billing_first_name']['priority'] = 10;
            $fields['billing']['billing_first_name']['class']    = ['form-row-first'];
            $fields['billing']['billing_first_name']['required'] = true;
        }

        if (isset($fields['billing']['billing_last_name'])) {
            $fields['billing']['billing_last_name']['label']    = 'اسم العائلة';
            $fields['billing']['billing_last_name']['priority'] = 20;
            $fields['billing']['billing_last_name']['class']    = ['form-row-last'];
            $fields['billing']['billing_last_name']['required'] = false;
        }

        if (isset($fields['billing']['billing_phone'])) {
            $fields['billing']['billing_phone']['label']    = 'رقم الجوال';
            $fields['billing']['billing_phone']['priority'] = 30;
            $fields['billing']['billing_phone']['class']    = ['form-row-wide'];
            $fields['billing']['billing_phone']['required'] = true;
            // If logged in via OTP, make read-only
            if (is_user_logged_in()) {
                $phone = get_user_meta(get_current_user_id(), 'billing_phone', true);
                if (!empty($phone)) {
                    $fields['billing']['billing_phone']['custom_attributes'] = ['readonly' => 'readonly'];
                }
            }
        }

        if (isset($fields['billing']['billing_email'])) {
            $fields['billing']['billing_email']['label']    = 'البريد الإلكتروني (اختياري)';
            $fields['billing']['billing_email']['priority'] = 40;
            $fields['billing']['billing_email']['class']    = ['form-row-wide'];
            $fields['billing']['billing_email']['required'] = false;
        }

        // ── City field (auto-filled from map, hidden) ──
        $fields['billing']['billing_city'] = [
            'type'     => 'hidden',
            'label'    => 'المدينة',
            'required' => true,
            'priority' => 80,
            'default'  => $this->get_saved_city(),
        ];

        // ── Address 1 — auto-filled from map, but editable ──
        if (isset($fields['billing']['billing_address_1'])) {
            $fields['billing']['billing_address_1']['label']       = 'تفاصيل العنوان (رقم المبنى، الشقة)';
            $fields['billing']['billing_address_1']['priority']    = 90;
            $fields['billing']['billing_address_1']['class']       = ['form-row-wide'];
            $fields['billing']['billing_address_1']['placeholder'] = 'مثال: فيلا 12، شارع الملك فهد';
            $fields['billing']['billing_address_1']['required']    = false;
        }

        // ── Hidden lat/lng fields for order storage ──
        $fields['billing']['billing_zooboxi_lat'] = [
            'type'     => 'hidden',
            'priority' => 95,
            'default'  => '',
        ];
        $fields['billing']['billing_zooboxi_lng'] = [
            'type'     => 'hidden',
            'priority' => 96,
            'default'  => '',
        ];

        return $fields;
    }

    /**
     * Translate default WooCommerce address fields to Arabic.
     */
    public function translate_fields(array $fields): array
    {
        if (isset($fields['first_name'])) $fields['first_name']['label'] = 'الاسم الأول';
        if (isset($fields['last_name']))  $fields['last_name']['label']  = 'اسم العائلة';
        if (isset($fields['address_1'])) {
            $fields['address_1']['label'] = 'تفاصيل العنوان';
            $fields['address_1']['placeholder'] = 'رقم المبنى، الشقة';
        }
        if (isset($fields['city']))    $fields['city']['label']    = 'المدينة';
        if (isset($fields['country'])) $fields['country']['label'] = 'البلد';

        return $fields;
    }

    /* ─────────────────────────────────────────────
     * Pre-fill Values from User Profile
     * ───────────────────────────────────────────── */

    public function prefill_values($value, string $input)
    {
        if (!is_user_logged_in()) return $value;

        $userId = get_current_user_id();

        switch ($input) {
            case 'billing_first_name':
                return get_user_meta($userId, 'billing_first_name', true) ?: get_user_meta($userId, 'first_name', true);
            case 'billing_last_name':
                return get_user_meta($userId, 'billing_last_name', true) ?: get_user_meta($userId, 'last_name', true);
            case 'billing_phone':
                return get_user_meta($userId, 'billing_phone', true);
            case 'billing_email':
                $email = get_user_meta($userId, 'billing_email', true);
                $userEmail = wp_get_current_user()->user_email;
                // Don't show placeholder emails
                if (!empty($email) && !str_contains($email, '@zooboxi.local')) return $email;
                if (!empty($userEmail) && !str_contains($userEmail, '@zooboxi.local')) return $userEmail;
                return '';
            case 'billing_country':
                return 'SA';
            case 'billing_city':
                return $this->get_saved_city();
        }

        return $value;
    }

    /* ─────────────────────────────────────────────
     * Render Checkout Map
     * ───────────────────────────────────────────── */

    public function render_checkout_map(): void
    {
        $mapsKey = get_option('zooboxi_google_maps_api_key', '');
        if (empty($mapsKey)) return;

        // Get saved location
        $lat = $this->get_saved_lat();
        $lng = $this->get_saved_lng();
        $city = $this->get_saved_city();
        ?>
        <div id="zbx-checkout-map-section" class="zbx-checkout-map-section">
            <h3 class="zbx-checkout-map-title">📍 <?php esc_html_e('موقع التوصيل', 'zooboxi'); ?></h3>
            <p class="zbx-checkout-map-desc"><?php esc_html_e('حرّك الخريطة لتحديد موقع التوصيل بدقة', 'zooboxi'); ?></p>

            <div class="zbx-checkout-map-wrap">
                <div id="zbx-checkout-map" class="zbx-checkout-map"></div>
                <div class="zbx-checkout-map-pin">📍</div>
                <button type="button" id="zbx-checkout-gps-btn" class="zbx-checkout-gps-btn" title="موقعي الحالي">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3"/><circle cx="12" cy="12" r="8"/></svg>
                </button>
            </div>

            <div id="zbx-checkout-address" class="zbx-checkout-address" style="display:none;"></div>
            <div id="zbx-checkout-delivery-info" class="zbx-checkout-delivery-info" style="display:none;"></div>
        </div>

        <style>
        .zbx-checkout-map-section {
            margin-bottom: 24px; padding: 20px; background: #f8faf8;
            border-radius: 16px; border: 2px solid #e0e8e0;
        }
        .zbx-checkout-map-title {
            font-size: 17px; font-weight: 700; color: #2c3e2d; margin: 0 0 4px;
            font-family: 'El Messiri', 'Tajawal', sans-serif;
        }
        .zbx-checkout-map-desc { font-size: 12px; color: #888; margin: 0 0 12px; }

        .zbx-checkout-map-wrap {
            position: relative; width: 100%; height: 260px;
            border-radius: 14px; overflow: hidden; border: 2px solid #d0d8d0;
        }
        .zbx-checkout-map { width: 100%; height: 100%; }
        .zbx-checkout-map-pin {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -100%);
            font-size: 32px; pointer-events: none; z-index: 5;
            filter: drop-shadow(0 3px 6px rgba(0,0,0,0.3));
            transition: transform 0.15s;
        }

        .zbx-checkout-gps-btn {
            position: absolute; bottom: 12px; right: 12px; z-index: 5;
            width: 40px; height: 40px; border-radius: 10px;
            background: #fff !important; border: 2px solid #d0d8d0 !important;
            display: flex; align-items: center; justify-content: center;
            cursor: pointer; color: #429d9c; box-shadow: 0 2px 8px rgba(0,0,0,0.12);
            transition: all 0.2s;
        }
        .zbx-checkout-gps-btn:hover { border-color: #429d9c !important; background: #f0f8f8 !important; }

        .zbx-checkout-address {
            margin-top: 10px; padding: 10px 14px; background: #fff;
            border-radius: 10px; border: 1px solid #e0e8e0;
            font-size: 13px; font-weight: 500; color: #333;
        }

        .zbx-checkout-delivery-info {
            margin-top: 8px; padding: 10px 14px; border-radius: 10px;
            font-size: 12px; font-weight: 600;
        }
        .zbx-checkout-delivery-info.express {
            background: #e8f8e8; color: #27ae60; border: 1px solid #c3e6c3;
        }
        .zbx-checkout-delivery-info.standard {
            background: #e8f0f8; color: #2980b9; border: 1px solid #c3d6e6;
        }
        .zbx-checkout-delivery-info.shipping {
            background: #fff8e8; color: #e67e22; border: 1px solid #f0deb8;
        }

        @media (max-width: 480px) {
            .zbx-checkout-map-section { padding: 14px; }
            .zbx-checkout-map-wrap { height: 220px; }
        }
        </style>

        <script>
        (function(){
            var zbxCheckoutMap, zbxGeocoder, zbxDebounceTimer;
            var savedLat = <?php echo $lat ? (float)$lat : 24.7136; ?>;
            var savedLng = <?php echo $lng ? (float)$lng : 46.6753; ?>;

            window.zbxInitCheckoutMap = function() {
                var mapEl = document.getElementById('zbx-checkout-map');
                if (!mapEl) return;

                zbxCheckoutMap = new google.maps.Map(mapEl, {
                    center: {lat: savedLat, lng: savedLng},
                    zoom: savedLat !== 24.7136 ? 16 : 13,
                    disableDefaultUI: true,
                    zoomControl: true,
                    gestureHandling: 'greedy',
                    styles: [
                        {featureType: "poi", stylers: [{visibility: "off"}]},
                        {featureType: "transit", stylers: [{visibility: "off"}]}
                    ]
                });

                zbxGeocoder = new google.maps.Geocoder();

                // On map idle → reverse geocode + update shipping
                zbxCheckoutMap.addListener('idle', function() {
                    var center = zbxCheckoutMap.getCenter();
                    var lat = center.lat();
                    var lng = center.lng();

                    // Update hidden fields
                    var latField = document.querySelector('[name="billing_zooboxi_lat"]');
                    var lngField = document.querySelector('[name="billing_zooboxi_lng"]');
                    if (latField) latField.value = lat;
                    if (lngField) lngField.value = lng;

                    // Bounce pin
                    var pin = document.querySelector('.zbx-checkout-map-pin');
                    if (pin) { pin.style.transform = 'translate(-50%, -120%)'; setTimeout(function(){ pin.style.transform = 'translate(-50%, -100%)'; }, 200); }

                    // Debounced reverse geocode + shipping update
                    clearTimeout(zbxDebounceTimer);
                    zbxDebounceTimer = setTimeout(function() {
                        // Reverse geocode
                        zbxGeocoder.geocode({location: {lat: lat, lng: lng}}, function(results, status) {
                            var addrEl = document.getElementById('zbx-checkout-address');
                            if (status === 'OK' && results[0]) {
                                addrEl.textContent = '📍 ' + results[0].formatted_address;
                                addrEl.style.display = 'block';

                                // Extract city from components
                                var city = '';
                                results[0].address_components.forEach(function(c) {
                                    if (c.types.includes('locality') || c.types.includes('administrative_area_level_2')) {
                                        city = c.long_name;
                                    }
                                });
                                var cityField = document.querySelector('[name="billing_city"]');
                                if (cityField && city) cityField.value = city;
                            }
                        });

                        // Update shipping via AJAX
                        if (typeof jQuery !== 'undefined' && typeof zooboxiData !== 'undefined') {
                            jQuery.post(zooboxiData.ajaxUrl, {
                                action: 'zooboxi_update_checkout_location',
                                nonce: zooboxiData.nonce,
                                lat: lat,
                                lng: lng
                            }).done(function(res) {
                                if (res.success) {
                                    // Show delivery info
                                    var infoEl = document.getElementById('zbx-checkout-delivery-info');
                                    if (res.data.express) {
                                        infoEl.className = 'zbx-checkout-delivery-info express';
                                        infoEl.textContent = '⚡ التوصيل السريع متاح لموقعك!';
                                    } else if (res.data.standard) {
                                        infoEl.className = 'zbx-checkout-delivery-info standard';
                                        infoEl.textContent = '📦 توصيل عادي خلال 24 ساعة';
                                    } else {
                                        infoEl.className = 'zbx-checkout-delivery-info shipping';
                                        infoEl.textContent = '🚚 شحن عادي 4-5 أيام عمل';
                                    }
                                    infoEl.style.display = 'block';

                                    // Trigger WooCommerce checkout update
                                    jQuery('body').trigger('update_checkout');
                                }
                            });
                        }
                    }, 700);
                });
            };

            // GPS button
            document.addEventListener('click', function(e) {
                if (e.target.closest('#zbx-checkout-gps-btn')) {
                    if (!navigator.geolocation) return;
                    var btn = e.target.closest('#zbx-checkout-gps-btn');
                    btn.style.color = '#888';
                    navigator.geolocation.getCurrentPosition(function(pos) {
                        if (zbxCheckoutMap) {
                            zbxCheckoutMap.setCenter({lat: pos.coords.latitude, lng: pos.coords.longitude});
                            zbxCheckoutMap.setZoom(17);
                        }
                        btn.style.color = '#429d9c';
                    }, function() {
                        btn.style.color = '#e74c3c';
                        setTimeout(function() { btn.style.color = '#429d9c'; }, 2000);
                    }, {enableHighAccuracy: true, timeout: 8000});
                }
            });

            // Load Google Maps ONCE. The location popup injects its own async tag on
            // every page, so "google is undefined" here does not mean "nobody is
            // loading it" — appending a second tag made the API load twice, which
            // Google answers with a 400 and an intermittently blank map.
            function zbxStartCheckoutMap() {
                if (typeof google !== 'undefined' && typeof google.maps !== 'undefined') {
                    zbxInitCheckoutMap();
                    return;
                }
                // The location popup prints its own async tag later in the footer, so
                // this check must run once the document is parsed — otherwise we race
                // it, load the API twice, and Google answers 400 with a blank map.
                if (document.querySelector('script[src*="maps.googleapis.com/maps/api/js"]')) {
                    var zbxMapWait = setInterval(function () {
                        if (typeof google !== 'undefined' && typeof google.maps !== 'undefined') {
                            clearInterval(zbxMapWait);
                            zbxInitCheckoutMap();
                        }
                    }, 120);
                    setTimeout(function () { clearInterval(zbxMapWait); }, 15000);
                    return;
                }
                var script = document.createElement('script');
                script.src = 'https://maps.googleapis.com/maps/api/js?key=<?php echo esc_attr($mapsKey); ?>&callback=zbxInitCheckoutMap';
                script.async = true;
                script.defer = true;
                document.body.appendChild(script);
            }
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', zbxStartCheckoutMap);
            } else {
                zbxStartCheckoutMap();
            }
        })();
        </script>
        <?php
    }

    /* ─────────────────────────────────────────────
     * AJAX: Update location during checkout
     * ───────────────────────────────────────────── */

    public static function ajax_update_checkout_location(): void
    {
        check_ajax_referer('zooboxi_nonce', 'nonce');

        $lat = (float) sanitize_text_field($_POST['lat'] ?? 0);
        $lng = (float) sanitize_text_field($_POST['lng'] ?? 0);

        if (!$lat || !$lng) {
            wp_send_json_error(['message' => 'Invalid coordinates']);
        }

        // Reverse geocode for city
        $geo = Zooboxi_Location_Detector::reverse_geocode($lat, $lng);
        $city = $geo['city'];

        // Update session
        if (function_exists('WC') && WC()->session) {
            WC()->session->set('zooboxi_customer_lat', $lat);
            WC()->session->set('zooboxi_customer_lng', $lng);
            if (!empty($city)) {
                WC()->session->set('zooboxi_customer_city', $city);
            }
            WC()->session->set('zooboxi_customer_district', $geo['district'] ?? '');
        }

        // Update cookies
        setcookie('zooboxi_lat', (string) $lat, time() + 86400 * 30, '/');
        setcookie('zooboxi_lng', (string) $lng, time() + 86400 * 30, '/');
        if (!empty($city)) {
            setcookie('zooboxi_city', $city, time() + 86400 * 30, '/');
        }

        // Detect delivery options for new location
        $options = Zooboxi_Delivery_Engine::detect_options($lat, $lng, [], $city ?: null);

        // Delete shipping transients to force recalculation
        $packages = WC()->cart ? WC()->cart->get_shipping_packages() : [];
        foreach ($packages as $key => $package) {
            $hashKey = 'wc_ship_' . md5(wp_json_encode($package));
            delete_transient($hashKey);
        }

        // Update session with new delivery type
        $best = $options['express'] ?? $options['standard'] ?? $options['shipping'] ?? null;
        if ($best && WC()->session) {
            WC()->session->set('zooboxi_warehouse_code', $best['warehouse_code']);
            WC()->session->set('zooboxi_delivery_type', $best['delivery_type']);
        }

        wp_send_json_success([
            'express'  => !empty($options['express']),
            'standard' => !empty($options['standard']),
            'shipping' => !empty($options['shipping']),
            'city'     => $city,
            'district' => $geo['district'] ?? '',
        ]);
    }

    /* ─────────────────────────────────────────────
     * Enqueue Checkout Assets
     * ───────────────────────────────────────────── */

    public function enqueue_checkout_assets(): void
    {
        if (!is_checkout()) return;

        // Add style for readonly phone field
        wp_add_inline_style('woocommerce-general', '
            #billing_phone[readonly] {
                background: #f0f0f0 !important;
                color: #666 !important;
                cursor: not-allowed;
                border-color: #ddd !important;
            }
        ');
    }

    /* ─────────────────────────────────────────────
     * Save Delivery Meta to Order
     * ───────────────────────────────────────────── */

    public function save_delivery_meta(int $orderId): void
    {
        $session = WC()->session;
        if (!$session) return;

        $order = wc_get_order($orderId);
        if (!$order) return;

        $order->update_meta_data('_zooboxi_warehouse', $session->get('zooboxi_warehouse_code', ''));
        $order->update_meta_data('_zooboxi_delivery_type', $session->get('zooboxi_delivery_type', ''));
        $order->update_meta_data('_zooboxi_lat', $session->get('zooboxi_customer_lat', ''));
        $order->update_meta_data('_zooboxi_lng', $session->get('zooboxi_customer_lng', ''));

        // Save cart analysis with per-item delivery info
        $analysis = $session->get('zooboxi_cart_analysis', []);
        if (!empty($analysis)) {
            $order->update_meta_data('_zooboxi_cart_analysis', wp_json_encode($analysis));
        }

        $order->save();
    }

    /**
     * Save checkout map coordinates to order.
     */
    public function save_map_meta(int $orderId): void
    {
        $order = wc_get_order($orderId);
        if (!$order) return;

        $lat = sanitize_text_field($_POST['billing_zooboxi_lat'] ?? '');
        $lng = sanitize_text_field($_POST['billing_zooboxi_lng'] ?? '');

        if (!empty($lat) && !empty($lng)) {
            $order->update_meta_data('_zooboxi_checkout_lat', $lat);
            $order->update_meta_data('_zooboxi_checkout_lng', $lng);
            $order->save();
        }
    }

    /* ─────────────────────────────────────────────
     * Delivery Summary (Before Order Review)
     * ───────────────────────────────────────────── */

    public function render_delivery_summary(): void
    {
        $session = WC()->session;
        if (!$session) return;

        $analysis = $session->get('zooboxi_cart_analysis', []);
        $type = $analysis['overall_type'] ?? $session->get('zooboxi_delivery_type', '');
        if (empty($type)) return;

        $labels = [
            'express'  => '⚡ ' . __('توصيل سريع — خلال ساعتين', 'zooboxi'),
            'same_day' => '📦 ' . __('توصيل عادي — خلال 24 ساعة', 'zooboxi'),
            'shipping' => '🚚 ' . __('شحن عادي — 4-5 أيام عمل', 'zooboxi'),
            'pickup'   => '🏬 ' . __('استلام من الفرع', 'zooboxi'),
        ];

        $label = $labels[$type] ?? $type;
        $summary = $analysis['summary'] ?? '';

        $cssClass = match ($type) {
            'express'  => 'express',
            'same_day' => 'standard',
            default    => 'shipping',
        };
        ?>
        <div class="zooboxi-checkout-delivery zooboxi-checkout-delivery--<?php echo esc_attr($cssClass); ?>">
            <div class="zooboxi-checkout-delivery__type"><?php echo esc_html($label); ?></div>
            <?php if (!empty($summary)): ?>
            <div class="zooboxi-checkout-delivery__summary"><?php echo esc_html($summary); ?></div>
            <?php endif; ?>
        </div>
        <?php
    }

    /* ─────────────────────────────────────────────
     * Helpers
     * ───────────────────────────────────────────── */

    private function get_saved_lat(): string
    {
        if (function_exists('WC') && WC()->session) {
            $val = WC()->session->get('zooboxi_customer_lat', '');
            if (!empty($val)) return (string) $val;
        }
        return $_COOKIE['zooboxi_lat'] ?? '';
    }

    private function get_saved_lng(): string
    {
        if (function_exists('WC') && WC()->session) {
            $val = WC()->session->get('zooboxi_customer_lng', '');
            if (!empty($val)) return (string) $val;
        }
        return $_COOKIE['zooboxi_lng'] ?? '';
    }

    private function get_saved_city(): string
    {
        if (function_exists('WC') && WC()->session) {
            $val = WC()->session->get('zooboxi_customer_city', '');
            if (!empty($val)) return $val;
        }
        return $_COOKIE['zooboxi_city'] ?? '';
    }
}
