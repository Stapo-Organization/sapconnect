<?php
/**
 * Cart, checkout and order-received behaviour carried over VERBATIM from the
 * previous theme (zooboxi-child functions.php, live copy of 2026-10-19).
 * These are production fixes (checkout map AJAX, Arabic copy, tax rows,
 * city/district fields, the order-received page) — not presentation, so they
 * travel unchanged. Only the asset handle in the city-map localisation and
 * the old toast/stepper/quick-view UI were left behind.
 */

defined('ABSPATH') || exit;

// ═══════════ PRODUCT PAGE CLEANUP ═══════════
// Hide the SKU line when there is no SKU (it printed "رمز المنتج: غير محدد").
add_filter('wc_product_sku_enabled', function ($enabled) {
    if (!is_product()) return $enabled;
    global $product;
    return ($product instanceof WC_Product && $product->get_sku()) ? $enabled : false;
});

// A clearer label than the raw attribute name ("اختر").
add_filter('woocommerce_attribute_label', function ($label, $name) {
    if (get_locale() !== 'ar') return $label;
    $n = strtolower((string) $name);
    if ($n === 'pa_choose-opt' || trim((string) $label) === 'اختر') {
        return 'اختر الخيار';
    }
    return $label;
}, 10, 2);


// ═══════════ WOOCOMMERCE CART LOCALIZATION ═══════════
add_filter('gettext', function($translated_text, $text, $domain) {
    if ($domain === 'woocommerce') {
        if (get_locale() === 'ar') {
            switch ($text) {
                case 'Cart totals':
                case 'Cart Totals':
                    return 'ملخص الإجمالي';
                case 'Apply coupon':
                    return 'تطبيق';
                case 'Coupon code':
                    return 'أدخل قسيمة الخصم';
                case 'Proceed to checkout':
                case 'Proceed to Checkout':
                    return 'إتمام الطلب';
                case 'Subtotal':
                    return 'المجموع الفرعي';
                case 'Total':
                    return 'المجموع';
                case 'Tax':
                    return 'ضريبة';
                case 'VAT':
                    return 'ضريبة القيمة المضافة';
                case 'Product':
                    return 'المنتج';
                case 'Quantity':
                    return 'الكمية';
                case 'Price':
                    return 'السعر';
                case 'Shipping':
                case 'Shipment':
                    return 'الشحن';
                case 'Select options':
                    return 'خيارات المنتج';
                case 'Add to cart':
                    return 'أضف للسلة';
                case 'Update cart':
                    return 'تحديث السلة';
                case 'Remove this item':
                    return 'إزالة';
                case 'Shipping options will be updated during checkout.':
                    return 'سيتم تحديث خيارات الشحن عند إتمام الطلب.';
            }
            // Fix "includes VAT/Tax"
            if (strpos($text, 'includes') !== false) {
                $translated = str_replace('includes', 'يشمل', $text);
                $translated = str_replace('VAT', 'ضريبة القيمة المضافة', $translated);
                $translated = str_replace('Tax', 'ضريبة', $translated);
                return $translated;
            }
        }
    }
    return $translated_text;
}, 20, 3);


// ═══════════ TRANSLATE DYNAMIC TAX LABEL (VAT) ═══════════
add_filter('woocommerce_rate_label', function($label, $rate_id) {
    if (get_locale() === 'ar' && (strtolower($label) === 'vat' || strtolower($label) === 'value added tax')) {
        return 'ضريبة القيمة المضافة';
    }
    return $label;
}, 10, 2);


// ═══════════ AJAX HANDLER: UPDATE CART QTY ═══════════
add_action('wp_ajax_zooboxi_update_cart_qty', 'zooboxi_update_cart_qty');
add_action('wp_ajax_nopriv_zooboxi_update_cart_qty', 'zooboxi_update_cart_qty');

function zooboxi_update_cart_qty() {
    check_ajax_referer('woocommerce-cart', 'security');
    
    $product_id = absint($_POST['product_id'] ?? 0);
    $direction  = sanitize_text_field($_POST['direction'] ?? '');
    
    if (!$product_id || !WC()->cart) {
        wp_send_json_error('Invalid request');
        return;
    }
    
    // Find cart item key for this product
    $cart_item_key = '';
    $current_qty = 0;
    foreach (WC()->cart->get_cart() as $key => $item) {
        if ($item['product_id'] == $product_id) {
            $cart_item_key = $key;
            $current_qty = $item['quantity'];
            break;
        }
    }
    
    if ($direction === 'remove' && $cart_item_key) {
        WC()->cart->remove_cart_item($cart_item_key);
        wp_send_json_success(['qty' => 0, 'key' => '']);
        return;
    }
    
    if ($direction === 'plus') {
        if ($cart_item_key) {
            WC()->cart->set_quantity($cart_item_key, $current_qty + 1);
            wp_send_json_success(['qty' => $current_qty + 1, 'key' => $cart_item_key]);
        } else {
            $new_key = WC()->cart->add_to_cart($product_id);
            wp_send_json_success(['qty' => 1, 'key' => $new_key]);
        }
        return;
    }
    
    if ($direction === 'minus' && $cart_item_key) {
        $new_qty = max(0, $current_qty - 1);
        if ($new_qty === 0) {
            WC()->cart->remove_cart_item($cart_item_key);
            wp_send_json_success(['qty' => 0, 'key' => '']);
        } else {
            WC()->cart->set_quantity($cart_item_key, $new_qty);
            wp_send_json_success(['qty' => $new_qty, 'key' => $cart_item_key]);
        }
        return;
    }
    
    wp_send_json_error('Unknown direction');
}


// ═══════════ ARABIC CITY DISPLAY NAMES ═══════════
// Google reverse-geocoding stores English city names in the location cookie
// ("Riyadh"). Matching logic stays untouched — this maps DISPLAY ONLY.
if (!function_exists('zooboxi_city_ar_map')) {
    function zooboxi_city_ar_map(): array {
        static $map = [
            'riyadh' => 'الرياض', 'jeddah' => 'جدة', 'jiddah' => 'جدة',
            'makkah' => 'مكة المكرمة', 'mecca' => 'مكة المكرمة',
            'medina' => 'المدينة المنورة', 'madinah' => 'المدينة المنورة', 'al madinah' => 'المدينة المنورة',
            'dammam' => 'الدمام', 'ad dammam' => 'الدمام', 'khobar' => 'الخبر', 'al khobar' => 'الخبر',
            'dhahran' => 'الظهران', 'jubail' => 'الجبيل', 'al jubail' => 'الجبيل',
            'qatif' => 'القطيف', 'hofuf' => 'الهفوف', 'al hofuf' => 'الهفوف',
            'al ahsa' => 'الأحساء', 'hafar al batin' => 'حفر الباطن',
            'taif' => 'الطائف', 'at taif' => 'الطائف', 'tabuk' => 'تبوك',
            'buraydah' => 'بريدة', 'buraidah' => 'بريدة', 'unaizah' => 'عنيزة', 'unayzah' => 'عنيزة',
            'hail' => 'حائل', "ha'il" => 'حائل', 'abha' => 'أبها',
            'khamis mushait' => 'خميس مشيط', 'khamis mushayt' => 'خميس مشيط',
            'najran' => 'نجران', 'jazan' => 'جازان', 'jizan' => 'جازان',
            'yanbu' => 'ينبع', 'al kharj' => 'الخرج', 'al qassim' => 'القصيم',
            'sakaka' => 'سكاكا', 'arar' => 'عرعر', 'al baha' => 'الباحة', 'al bahah' => 'الباحة',
            // regions/provinces as Google reverse-geocoding returns them
            'riyadh principality' => 'منطقة الرياض', 'riyadh province' => 'منطقة الرياض', 'riyadh region' => 'منطقة الرياض',
            'makkah province' => 'منطقة مكة المكرمة', 'makkah region' => 'منطقة مكة المكرمة', 'mecca region' => 'منطقة مكة المكرمة',
            'al madinah province' => 'منطقة المدينة المنورة', 'medina region' => 'منطقة المدينة المنورة', 'al madinah region' => 'منطقة المدينة المنورة',
            'eastern province' => 'المنطقة الشرقية', 'eastern region' => 'المنطقة الشرقية', 'ash sharqiyah' => 'المنطقة الشرقية',
            'al qassim province' => 'منطقة القصيم', 'qassim region' => 'منطقة القصيم', 'al qassim region' => 'منطقة القصيم',
            'asir province' => 'منطقة عسير', 'asir region' => 'منطقة عسير', "'asir region" => 'منطقة عسير',
            'tabuk province' => 'منطقة تبوك', 'tabuk region' => 'منطقة تبوك',
            'hail province' => 'منطقة حائل', 'hail region' => 'منطقة حائل', "ha'il region" => 'منطقة حائل',
            'northern borders province' => 'منطقة الحدود الشمالية', 'northern borders region' => 'منطقة الحدود الشمالية',
            'jazan province' => 'منطقة جازان', 'jazan region' => 'منطقة جازان',
            'najran province' => 'منطقة نجران', 'najran region' => 'منطقة نجران',
            'al bahah province' => 'منطقة الباحة', 'al baha region' => 'منطقة الباحة',
            'al jawf province' => 'منطقة الجوف', 'al jawf region' => 'منطقة الجوف',
        ];
        return $map;
    }
}
if (!function_exists('zooboxi_city_ar')) {
    function zooboxi_city_ar(string $city): string {
        $map = zooboxi_city_ar_map();
        $k = strtolower(trim($city));
        return $map[$k] ?? $city;
    }
}

// ═══════════ CART TOTALS: NO DOUBLE EMOJI ═══════════
// The package heading already carries the tier emoji (🚀 شحنة التوصيل السريع);
// the method chip inside repeats it — strip leading emojis from the chip label.
add_filter('woocommerce_cart_shipping_method_full_label', function ($label, $method) {
    $label = preg_replace('/^[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}\x{200D}]+\s*/u', '', $label);
    // drop the raw "NAME:" colon before the price — the chip's flex gap separates them
    return preg_replace('/:\s*(<span)/u', ' $1', $label);
}, 10, 2);

// ═══════════ ARABIC SHIPPING DESTINATION ═══════════
// Google reverse-geocoding stores English city/region names in the customer
// address ("Riyadh Principality") — map them for the «الشحن إلى …» line.
// Zooboxi shipping matches by coordinates, so this is display-safe.
add_filter('woocommerce_cart_shipping_packages', function ($packages) {
    if (!function_exists('zooboxi_city_ar')) return $packages;
    foreach ($packages as &$p) {
        foreach (['city', 'state'] as $k) {
            if (!empty($p['destination'][$k]) && is_string($p['destination'][$k])) {
                $p['destination'][$k] = zooboxi_city_ar($p['destination'][$k]);
            }
        }
    }
    return $packages;
}, 20);


// ═══════════ CART COPY: SHORTER, CLEARER, NON-REPEATING ═══════════
add_filter('gettext', function ($translated, $text, $domain) {
    if ('woocommerce' !== $domain || get_locale() !== 'ar') {
        return $translated;
    }
    switch ($text) {
        case 'Cart totals':
        case 'Cart Totals':
            return 'ملخص الطلب';
        case 'Total':
            return 'الإجمالي';
        case '(includes %s)':
            return 'شامل %s';
        case 'Shipping to %s.':
            return 'التوصيل إلى %s';
        case 'Change address':
            return 'تغيير';
        case 'Subtotal':
            // Piece count belongs on the CART's totals row only — on checkout the
            // same string is also the review table's column header, where it reads wrong.
            if (is_cart() && !is_checkout() && function_exists('WC') && WC()->cart) {
                $n = (int) WC()->cart->get_cart_contents_count();
                if ($n > 0) {
                    // Arabic counts: 1 and 2 read better without the numeral
                    if (1 === $n) { $count = 'قطعة واحدة'; }
                    elseif (2 === $n) { $count = 'قطعتان'; }
                    elseif ($n <= 10) { $count = $n . ' قطع'; }
                    else { $count = $n . ' قطعة'; }
                    return 'المجموع الفرعي · ' . $count;
                }
            }
            return 'المجموع الفرعي';
    }
    return $translated;
}, 30, 3);

// ═══════════ SHIPPING ROW: NO REPEATED TIER NAME ═══════════
// The package heading already names the tier ("🚚 شحنة اليوم التالي"). When a
// package offers a single rate, the chip repeating that name is noise — show
// the price alone (or «مجاني»). With 2+ rates the names stay: they're choices.
add_filter('woocommerce_cart_shipping_method_full_label', function ($label, $method) {
    $label = preg_replace('/^[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}\x{200D}]+\s*/u', '', $label);
    $label = preg_replace('/:\s*(<span)/u', ' $1', $label);

    if (!function_exists('WC') || !WC()->shipping()) {
        return $label;
    }
    $alone = false;
    foreach (WC()->shipping()->get_packages() as $package) {
        if (isset($package['rates'][$method->get_id()])) {
            $alone = (count($package['rates']) === 1);
            break;
        }
    }
    if (!$alone) {
        return $label;
    }
    $cost = (float) $method->get_cost() + (float) $method->get_shipping_tax();
    return $cost > 0
        ? wc_price($cost)
        : '<span class="zbx-free-ship">مجاني</span>';
}, 20, 2);

// ═══════════ CHECKOUT: ARABIC PAYMENT METHODS ═══════════
// The store is Arabic-only; gateways ship English titles/descriptions.
add_filter('woocommerce_gateway_title', function ($title, $id) {
    if (get_locale() !== 'ar') return $title;
    if ('cod' === $id) return 'الدفع عند الاستلام';
    if (false !== strpos((string) $id, 'myfatoorah')) return 'الدفع الإلكتروني';
    return $title;
}, 20, 2);

add_filter('woocommerce_gateway_description', function ($desc, $id) {
    if (get_locale() !== 'ar') return $desc;
    if ('cod' === $id) return 'ادفع نقداً أو بالشبكة لحظة استلام طلبك.';
    if (false !== strpos((string) $id, 'myfatoorah')) return 'ادفع بأمان عبر مدى · Apple Pay · STC Pay · أو بطاقتك البنكية.';
    return $desc;
}, 20, 2);

// ═══════════ CHECKOUT: NO DOUBLE "(اختياري)" ═══════════
// The plugin appends it to some labels while WooCommerce adds its own suffix.
add_filter('woocommerce_checkout_fields', function ($fields) {
    foreach ($fields as $group => $items) {
        foreach ($items as $key => $field) {
            if (!empty($field['label'])) {
                $fields[$group][$key]['label'] = trim(str_replace('(اختياري)', '', $field['label']));
            }
        }
    }
    return $fields;
}, 9999); // the plugin sets these labels at 999 — run after it

// ═══════════ CHECKOUT: DE-DUPLICATED DELIVERY BANNER ═══════════
// The plugin prints the tier line AND a summary that repeats it (with a
// "خلال خلال" typo). Buffer the hook and drop the echo when it repeats.
add_action('woocommerce_checkout_before_order_review', function () { ob_start(); }, 1);
add_action('woocommerce_checkout_before_order_review', function () {
    $html = ob_get_clean();
    if (!$html) { return; }

    $html = str_replace('خلال خلال', 'خلال', $html);

    if (preg_match('/__type">(.*?)<\/div>/su', $html, $t) &&
        preg_match('/__summary">(.*?)<\/div>/su', $html, $s)) {
        $type    = trim(wp_strip_all_tags($t[1]));
        $summary = trim(wp_strip_all_tags($s[1]));
        // the promise phrase lives after the em-dash: "توصيل عادي — خلال 24 ساعة"
        $promise = '';
        if (false !== strpos($type, '—')) {
            $promise = trim(substr($type, strpos($type, '—') + strlen('—')));
        }
        if ($promise !== '' && false !== mb_strpos($summary, $promise)) {
            $html = preg_replace('/<div class="[^"]*__summary">.*?<\/div>/su', '', $html, 1);
        }
    }
    // Hold it: printed here it lands BETWEEN the panel heading and the panel body,
    // splitting the order card in two. Re-emit it inside the card instead.
    $GLOBALS['zbx_delivery_banner'] = $html;
}, 999);

add_action('woocommerce_checkout_order_review', function () {
    if (!empty($GLOBALS['zbx_delivery_banner'])) {
        echo $GLOBALS['zbx_delivery_banner']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        $GLOBALS['zbx_delivery_banner'] = '';
    }
}, 5);

// ═══════════ CHECKOUT COPY ═══════════
add_filter('gettext', function ($translated, $text, $domain) {
    if ('woocommerce' !== $domain || get_locale() !== 'ar') {
        return $translated;
    }
    switch ($text) {
        case 'Billing details':   return 'بيانات التوصيل';
        case 'Your order':        return 'ملخص طلبك';
        case 'Order notes':       return 'ملاحظات للطلب';
        case 'Ship to a different address?': return 'التوصيل إلى عنوان آخر؟';
        case 'Place order':       return 'تأكيد الطلب والدفع';
        case 'Product':           return 'المنتج';
    }
    return $translated;
}, 99, 3);

// ═══════════ CHECKOUT: READABLE QUANTITY ═══════════
add_filter('woocommerce_checkout_cart_item_quantity', function ($html, $cart_item) {
    if (get_locale() !== 'ar') { return $html; }
    $qty = isset($cart_item['quantity']) ? (int) $cart_item['quantity'] : 0;
    return $qty > 0 ? '<span class="product-quantity">الكمية: ' . $qty . '</span>' : $html;
}, 10, 2);

// ═══════════ FIX: CHECKOUT MAP LOCATION UPDATE (AJAX 400) ═══════════
// The plugin REQUIREs Zooboxi_Checkout_Customizer during AJAX but only
// INSTANTIATES it when !is_admin() — so its wp_ajax hooks never registered and
// dragging the checkout map always failed with 400/"0" (shipping never
// recalculated for the new pin). The handler is static; register it directly.
if (!function_exists('zooboxi_ajax_checkout_location')) {
    function zooboxi_ajax_checkout_location() {
        if (is_callable(['Zooboxi_Checkout_Customizer', 'ajax_update_checkout_location'])) {
            Zooboxi_Checkout_Customizer::ajax_update_checkout_location(); // sends JSON + dies
        }
        wp_send_json_error(['message' => 'checkout location handler unavailable'], 500);
    }
}
add_action('wp_ajax_zooboxi_update_checkout_location', 'zooboxi_ajax_checkout_location');
add_action('wp_ajax_nopriv_zooboxi_update_checkout_location', 'zooboxi_ajax_checkout_location');

// ═══════════ TOTAL: TAX SHOWN AS ITS OWN ROW, NOT AN INLINE NOTE ═══════════
// A dedicated «الإجمالي قبل الضريبة» + «ضريبة القيمة المضافة» pair reads far
// clearer than "(شامل ...)" tucked under the total, so drop the inline note.
add_filter('woocommerce_cart_totals_order_total_html', function ($value) {
    if (get_locale() !== 'ar') {
        return $value;
    }
    return preg_replace('/<small class="includes_tax">.*?<\/small>/su', '', $value);
}, 20);

// Renders: net total, then one row per tax rate (label + percent + amount).
if (!function_exists('zooboxi_render_tax_breakdown')) {
    function zooboxi_render_tax_breakdown() {
        if (!function_exists('WC') || !WC()->cart || !wc_tax_enabled()) {
            return;
        }
        $tax = (float) WC()->cart->get_total_tax();
        if ($tax <= 0) {
            return;
        }
        $total = (float) WC()->cart->get_total('edit');
        $net   = max(0, $total - $tax);
        ?>
        <tr class="zbx-net-row">
            <th><?php esc_html_e('الإجمالي قبل الضريبة', 'zooboxi'); ?></th>
            <td><?php echo wp_kses_post(wc_price($net)); ?></td>
        </tr>
        <?php foreach ((array) WC()->cart->get_tax_totals() as $tt) :
            $rate_id = $tt->tax_rate_id ?? ($tt->rate_id ?? 0); // core exposes tax_rate_id
            $percent = $rate_id ? WC_Tax::get_rate_percent($rate_id) : '';
            $label   = isset($tt->label) ? $tt->label : __('ضريبة القيمة المضافة', 'zooboxi');
            ?>
            <tr class="zbx-vat-row">
                <th>
                    <?php echo esc_html($label); ?>
                    <?php if ($percent) : ?><span class="zbx-vat-rate"><?php echo esc_html($percent); ?></span><?php endif; ?>
                </th>
                <td><?php echo wp_kses_post($tt->formatted_amount); ?></td>
            </tr>
        <?php endforeach;
    }
}
add_action('woocommerce_cart_totals_before_order_total', 'zooboxi_render_tax_breakdown');
add_action('woocommerce_review_order_before_order_total', 'zooboxi_render_tax_breakdown');

// ═══════════ CHECKOUT: VISIBLE CITY + DISTRICT, TIED TO THE MAP ═══════════
// The address is chosen on the map, but the customer still needs to SEE the
// city and district it resolved to (and be able to correct the district).
add_filter('woocommerce_checkout_fields', function ($fields) {
    if (get_locale() !== 'ar') {
        return $fields;
    }
    $session  = function_exists('WC') ? WC()->session : null;
    $city     = $_COOKIE['zooboxi_city'] ?? ($session ? (string) $session->get('zooboxi_customer_city', '') : '');
    $district = $_COOKIE['zooboxi_district'] ?? ($session ? (string) $session->get('zooboxi_customer_district', '') : '');
    $city     = $city ? zooboxi_city_ar(sanitize_text_field(wp_unslash($city))) : '';
    $district = $district ? sanitize_text_field(wp_unslash($district)) : '';

    $fields['billing']['billing_city'] = [
        'type'        => 'text',
        'label'       => 'المدينة',
        'required'    => true,
        'priority'    => 78,
        'default'     => $city,
        'placeholder' => 'تُحدد من الخريطة',
        'class'       => ['form-row-first', 'zbx-map-field'],
    ];
    $fields['billing']['billing_address_2'] = [
        'type'        => 'text',
        'label'       => 'الحي',
        'required'    => false,
        'priority'    => 79,
        'default'     => $district,
        'placeholder' => 'يُملأ من الخريطة — عدّله إن لزم',
        'class'       => ['form-row-last', 'zbx-map-field'],
    ];
    return $fields;
}, 10000);

// Keep the map's own defaults in sync with those fields.
add_filter('woocommerce_checkout_get_value', function ($value, $input) {
    if (get_locale() !== 'ar') return $value;
    $session = function_exists('WC') ? WC()->session : null;
    if ('billing_city' === $input) {
        $c = $_COOKIE['zooboxi_city'] ?? ($session ? (string) $session->get('zooboxi_customer_city', '') : '');
        return $c ? zooboxi_city_ar(sanitize_text_field(wp_unslash($c))) : $value;
    }
    if ('billing_address_2' === $input) {
        $d = $_COOKIE['zooboxi_district'] ?? ($session ? (string) $session->get('zooboxi_customer_district', '') : '');
        return $d ? sanitize_text_field(wp_unslash($d)) : $value;
    }
    return $value;
}, 20, 2);


// ═══════════════════════════════════════════════════════════════
// ORDER RECEIVED — A CELEBRATION, NOT A RECEIPT DUMP
// The default page is a bare <ul> that even leaks the internal
// placeholder email. Replace it with a hero, a live order timeline,
// the delivery promise and clear next steps.
// ═══════════════════════════════════════════════════════════════
add_action('woocommerce_before_thankyou', function ($order_id) {
    $order = wc_get_order($order_id);
    if (!$order || get_locale() !== 'ar') {
        return;
    }

    // Delivery promise straight from the order's shipping lines.
    $promises = [];
    foreach ($order->get_shipping_methods() as $ship) {
        $name = trim(wp_strip_all_tags($ship->get_name()));
        if ($name !== '') { $promises[] = $name; }
    }

    // Where it is going (city + district, Arabic).
    $city     = trim((string) $order->get_billing_city()) ?: trim((string) $order->get_shipping_city());
    $city     = $city !== '' ? zooboxi_city_ar($city) : '';
    $district = trim((string) $order->get_billing_address_2()) ?: trim((string) $order->get_shipping_address_2());
    $parts    = array_filter([$district, $city], static function ($v) { return trim((string) $v) !== ''; });
    $place    = implode('، ', $parts);

    // Timeline state from the order status.
    $status = $order->get_status();
    $stage  = 1;
    if (in_array($status, ['processing', 'on-hold'], true)) { $stage = 2; }
    if (in_array($status, ['shipped', 'out-for-delivery'], true)) { $stage = 3; }
    if (in_array($status, ['completed'], true)) { $stage = 4; }

    $steps = [
        ['icon' => '📝', 'label' => 'استلمنا طلبك'],
        ['icon' => '📦', 'label' => 'قيد التجهيز'],
        ['icon' => '🚚', 'label' => 'في الطريق إليك'],
        ['icon' => '🎉', 'label' => 'وصل!'],
    ];

    $account = wc_get_page_permalink('myaccount');
    $shop    = wc_get_page_permalink('shop');
    ?>
    <div class="zbx-ty">
        <div class="zbx-ty-hero">
            <img class="zbx-ty-char zbx-ty-char--dog" src="<?php echo esc_url(zv_img('hero-dog-celebrate.webp')); ?>" alt="" width="600" height="888" aria-hidden="true">
            <img class="zbx-ty-char zbx-ty-char--cat" src="<?php echo esc_url(zv_img('hero-cat-celebrate.webp')); ?>" alt="" width="600" height="858" aria-hidden="true">
            <div class="zbx-ty-check" aria-hidden="true">
                <svg viewBox="0 0 52 52"><circle class="zbx-ty-ring" cx="26" cy="26" r="23" fill="none"/><path class="zbx-ty-tick" fill="none" d="M14 27l8 8 16-17"/></svg>
            </div>
            <h2 class="zbx-ty-title">تم استلام طلبك 🎉</h2>
            <p class="zbx-ty-sub">شكراً لك! بدأنا تجهيز طلبك، وأليفك على وشك أن يفرح.</p>

            <div class="zbx-ty-facts">
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">رقم الطلب</span>
                    <strong class="zbx-ty-fact-val">#<?php echo esc_html($order->get_order_number()); ?></strong>
                </div>
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">الإجمالي</span>
                    <strong class="zbx-ty-fact-val"><?php echo wp_kses_post($order->get_formatted_order_total()); ?></strong>
                </div>
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">وسيلة الدفع</span>
                    <strong class="zbx-ty-fact-val"><?php echo esc_html($order->get_payment_method_title()); ?></strong>
                </div>
                <div class="zbx-ty-fact">
                    <span class="zbx-ty-fact-cap">تاريخ الطلب</span>
                    <strong class="zbx-ty-fact-val"><?php echo esc_html(zooboxi_date_ar($order->get_date_created())); ?></strong>
                </div>
            </div>
        </div>

        <?php if (!empty($promises) || $place !== '') : ?>
        <div class="zbx-ty-promise">
            <?php if (!empty($promises)) : ?>
                <div class="zbx-ty-promise-row">
                    <span class="zbx-ty-promise-ic">⏱️</span>
                    <span><strong>موعد الوصول:</strong> <?php echo esc_html(implode(' · ', $promises)); ?></span>
                </div>
            <?php endif; ?>
            <?php if ($place !== '') : ?>
                <div class="zbx-ty-promise-row">
                    <span class="zbx-ty-promise-ic">📍</span>
                    <span><strong>سيصل إلى:</strong> <?php echo esc_html($place); ?></span>
                </div>
            <?php endif; ?>
        </div>
        <?php endif; ?>

        <div class="zbx-ty-timeline" role="list">
            <?php foreach ($steps as $i => $s) :
                $n = $i + 1;
                $cls = $n < $stage ? 'is-done' : ($n === $stage ? 'is-current' : '');
                ?>
                <div class="zbx-ty-step <?php echo esc_attr($cls); ?>" role="listitem">
                    <span class="zbx-ty-step-dot"><?php echo esc_html($s['icon']); ?></span>
                    <span class="zbx-ty-step-label"><?php echo esc_html($s['label']); ?></span>
                </div>
                <?php if ($n < count($steps)) : ?><span class="zbx-ty-step-line <?php echo $n < $stage ? 'is-filled' : ''; ?>"></span><?php endif; ?>
            <?php endforeach; ?>
        </div>

        <div class="zbx-ty-actions">
            <a class="zbx-ty-btn zbx-ty-btn--primary" href="<?php echo esc_url($account); ?>">📦 تتبّع طلبي</a>
            <a class="zbx-ty-btn" href="<?php echo esc_url($shop); ?>">🛍️ متابعة التسوق</a>
            <a class="zbx-ty-btn" href="mailto:info@zooboxi.com">💬 تواصل معنا</a>
        </div>
    </div>

    <script>
    (function () {
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
        var colors = ['#429D9C', '#D46856', '#F4BE2C', '#7CC6C2', '#2DB87B'];
        var wrap = document.createElement('div');
        wrap.className = 'zbx-confetti';
        for (var i = 0; i < 44; i++) {
            var s = document.createElement('span');
            s.style.left = (Math.random() * 100) + '%';
            s.style.background = colors[i % colors.length];
            s.style.animationDelay = (Math.random() * 0.7) + 's';
            s.style.animationDuration = (2.2 + Math.random() * 1.6) + 's';
            s.style.transform = 'rotate(' + (Math.random() * 360) + 'deg)';
            wrap.appendChild(s);
        }
        document.body.appendChild(wrap);
        setTimeout(function () { wrap.remove(); }, 4600);
    })();
    </script>
    <?php
}, 5);

// The COD gateway prints its English instructions on this page. Gateways are
// instantiated late, so swap the hook while the template is rendering.
add_action('woocommerce_before_thankyou', function () {
    if (get_locale() !== 'ar') return;
    remove_all_actions('woocommerce_thankyou_cod');
    add_action('woocommerce_thankyou_cod', function () {
        echo '<p class="zbx-ty-note">💵 جهّز المبلغ نقداً أو بالشبكة عند استلام طلبك.</p>';
    });
}, 1);

/** Arabic long date — date_i18n follows the site locale (en_US) here. */
if (!function_exists('zooboxi_date_ar')) {
    function zooboxi_date_ar($date): string {
        if (!$date) return '';
        static $months = [
            1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل', 5 => 'مايو', 6 => 'يونيو',
            7 => 'يوليو', 8 => 'أغسطس', 9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر',
        ];
        $d = (int) $date->date('j');
        $m = (int) $date->date('n');
        $y = (int) $date->date('Y');
        return $d . ' ' . ($months[$m] ?? '') . ' ' . $y;
    }
}
