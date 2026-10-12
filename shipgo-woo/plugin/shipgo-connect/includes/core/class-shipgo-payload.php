<?php
defined('ABSPATH') || exit;

/** Builds the normalized order payload ShipGo's /v1/channel/orders expects — full
 *  line, customer, billing + shipping detail, AND the precise map location: Zooboxi
 *  captures a pin (lat/lng), which we reverse-geocode to a complete Arabic address
 *  (street / district / city / postcode) so the warehouse & driver have an exact
 *  destination. */
class ShipGo_Payload {

    public static function for_order(WC_Order $order): array {
        $lines = [];
        foreach ($order->get_items() as $item) {
            /** @var WC_Order_Item_Product $item */
            $product = $item->get_product();
            $sku = $product ? $product->get_sku() : '';
            $qty = (float) $item->get_quantity();
            $unit = $qty > 0 ? round(((float) $item->get_total()) / $qty, 4) : 0.0;
            $lines[] = array_filter([
                'sku'       => (string) $sku,
                'qty'       => $qty,
                'price'     => $unit,
                'name'      => $item->get_name(),
                'item_code' => self::item_code($item, $product),
            ], static fn($v) => $v !== null && $v !== '');
        }

        $billing  = self::address($order, 'billing');
        $shipping = self::address($order, 'shipping');
        if (empty($shipping['address_1'])) {
            $shipping = $billing;   // "ship to billing"
        }

        // precise map pin + reverse-geocoded full address (the real delivery location)
        $geo = self::geo($order);
        if ($geo) {
            if (empty($shipping['address_1']) && !empty($geo['street'])) {
                $shipping['address_1'] = trim(($geo['street_number'] ?? '') . ' ' . $geo['street']);
            }
            foreach (['district' => 'district', 'city' => 'city', 'region' => 'state', 'postcode' => 'postcode'] as $g => $f) {
                if (!empty($geo[$g]) && empty($shipping[$f])) {
                    $shipping[$f] = $geo[$g];
                }
            }
            if (!empty($geo['formatted_address'])) {
                $shipping['formatted'] = $geo['formatted_address'];
            }
            $shipping['geo'] = ['lat' => $geo['lat'], 'lng' => $geo['lng'], 'maps_url' => $geo['maps_url']];
        }

        $payload = [
            'external_id'          => (string) $order->get_id(),
            'order_number'         => (string) $order->get_order_number(),
            'currency'             => $order->get_currency() ?: 'SAR',
            'store_status'         => $order->get_status(),
            'order_total'          => (float) $order->get_total(),
            'email'                => $order->get_billing_email(),
            'phone'                => $order->get_billing_phone(),
            'customer_note'        => $order->get_customer_note(),
            'payment_method'       => $order->get_payment_method(),
            'payment_method_title' => $order->get_payment_method_title(),
            'delivery_type'        => $order->get_meta('_zooboxi_delivery_type'),
            'billing'              => $billing,
            'shipping'             => $shipping,
            'ship_to'              => $shipping,   // back-compat (effective shipping address)
            'geo'                  => $geo,        // coordinates + reverse-geocoded components
            'lines'                => array_values($lines),
        ];
        return array_filter($payload, static fn($v) => $v !== '' && $v !== null);
    }

    /** Zooboxi keeps the SAP item code in order-item / product meta — a resolver hint. */
    private static function item_code(WC_Order_Item_Product $item, $product): ?string {
        $code = $item->get_meta('_zooboxi_item_code');
        if (!$code && $product) {
            $code = $product->get_meta('_zooboxi_item_code');
        }
        return $code ?: null;
    }

    /**
     * The customer's map pin → coordinates + a Google Maps link, enriched with a
     * reverse-geocoded full Arabic address (cached on the order so retries don't
     * re-call the API). Falls back to coordinates-only if the geocode is unavailable.
     */
    private static function geo(WC_Order $o): ?array {
        $lat = $o->get_meta('_zooboxi_checkout_lat') ?: $o->get_meta('_billing_zooboxi_lat') ?: $o->get_meta('_zooboxi_lat');
        $lng = $o->get_meta('_zooboxi_checkout_lng') ?: $o->get_meta('_billing_zooboxi_lng') ?: $o->get_meta('_zooboxi_lng');
        if (!$lat || !$lng) {
            return null;
        }
        $lat = (float) $lat;
        $lng = (float) $lng;
        $geo = ['lat' => $lat, 'lng' => $lng, 'maps_url' => "https://www.google.com/maps/search/?api=1&query={$lat},{$lng}"];

        $cached = $o->get_meta('_shipgo_geo_address');
        if (is_array($cached) && !empty($cached)) {
            return array_merge($geo, $cached);
        }
        $key = get_option('zooboxi_google_maps_api_key');
        if (!$key) {
            return $geo;
        }
        $url = add_query_arg(
            ['latlng' => "{$lat},{$lng}", 'language' => 'ar', 'key' => $key],
            'https://maps.googleapis.com/maps/api/geocode/json'
        );
        $resp = wp_remote_get($url, ['timeout' => 8]);
        if (is_wp_error($resp)) {
            return $geo;
        }
        $b = json_decode(wp_remote_retrieve_body($resp), true);
        if (empty($b['results'][0])) {
            return $geo;
        }
        $addr = self::components($b['results'][0]['address_components'] ?? []);
        if (!empty($b['results'][0]['formatted_address'])) {
            $addr['formatted_address'] = $b['results'][0]['formatted_address'];
        }
        $addr = array_filter($addr, static fn($v) => $v !== null && $v !== '');
        if ($addr) {
            $o->update_meta_data('_shipgo_geo_address', $addr);
            $o->save();
        }
        return array_merge($geo, $addr);
    }

    /** Map Google address_components → flat keys. */
    private static function components(array $list): array {
        $map = [
            'street_number' => 'street_number', 'route' => 'street',
            'sublocality' => 'district', 'sublocality_level_1' => 'district', 'neighborhood' => 'district',
            'locality' => 'city', 'administrative_area_level_1' => 'region',
            'postal_code' => 'postcode', 'country' => 'country',
        ];
        $out = [];
        foreach ($list as $c) {
            foreach (($c['types'] ?? []) as $t) {
                if (isset($map[$t]) && empty($out[$map[$t]])) {
                    $out[$map[$t]] = $c['long_name'];
                }
            }
        }
        return $out;
    }

    /** Full structured address ($type = 'billing' | 'shipping') + a readable one-liner. */
    private static function address(WC_Order $order, string $type): array {
        $fields = ['first_name', 'last_name', 'company', 'address_1', 'address_2', 'city', 'state', 'postcode', 'country'];
        $a = [];
        foreach ($fields as $f) {
            $m = "get_{$type}_{$f}";
            $v = method_exists($order, $m) ? $order->$m() : '';
            if ($v !== '' && $v !== null) {
                $a[$f] = $v;
            }
        }
        $phone = $type === 'billing'
            ? $order->get_billing_phone()
            : (method_exists($order, 'get_shipping_phone') ? $order->get_shipping_phone() : '');
        if (!$phone && $type === 'shipping') {
            $phone = $order->get_billing_phone();
        }
        if ($phone) {
            $a['phone'] = $phone;
        }
        $name = trim(($a['first_name'] ?? '') . ' ' . ($a['last_name'] ?? ''));
        if ($name !== '') {
            $a['name'] = $name;
        }
        if (!empty($a['country']) && function_exists('WC') && WC()->countries) {
            $countries = WC()->countries->get_countries();
            if (isset($countries[$a['country']])) {
                $a['country_name'] = $countries[$a['country']];
            }
        }
        $oneliner = array_filter([
            $a['address_1'] ?? '', $a['address_2'] ?? '', $a['city'] ?? '',
            $a['state'] ?? '', $a['postcode'] ?? '', $a['country_name'] ?? ($a['country'] ?? ''),
        ], static fn($v) => $v !== '');
        if ($oneliner) {
            $a['formatted'] = implode('، ', $oneliner);
        }
        return $a;
    }
}
