<?php
/**
 * Smart Delivery Engine — determines the best delivery option
 * based on customer GPS location and warehouse proximity.
 */
class Zooboxi_Delivery_Engine
{
    public const TYPE_EXPRESS  = 'express';
    public const TYPE_STANDARD = 'same_day';
    public const TYPE_SHIPPING = 'shipping';
    public const TYPE_PICKUP   = 'pickup';

    /**
     * Determine all available delivery options for a customer location.
     *
     * @return array [
     *   'express'  => [...] | null,
     *   'standard' => [...] | null,
     *   'shipping' => [...],
     *   'pickup'   => [...],
     * ]
     */
    public static function detect_options(float $lat, float $lng, array $cartItems = []): array
    {
        $options = [
            'express'  => null,
            'standard' => null,
            'shipping' => null,
            'pickup'   => [],
        ];

        // 1. Express — nearest warehouse within radius
        $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
        if ($nearest && $nearest['distance'] <= (float) ($nearest['warehouse']['express_radius_km'] ?? 10)) {
            $wh = $nearest['warehouse'];
            $available = empty($cartItems) || Zooboxi_Stock_Manager::has_all_items($wh['warehouse_code'], $cartItems);

            if ($available) {
                $options['express'] = [
                    'delivery_type'  => self::TYPE_EXPRESS,
                    'warehouse_code' => $wh['warehouse_code'],
                    'warehouse_name' => is_rtl() ? ($wh['display_name_ar'] ?: $wh['display_name_en']) : ($wh['display_name_en'] ?: $wh['display_name_ar']),
                    'distance_km'    => $nearest['distance'],
                    'estimated_time' => __('خلال ساعتين', 'zooboxi'),
                    'fee'            => (float) get_option('zooboxi_express_fee', 15),
                ];
            }
        }

        // 2. Standard — central warehouse in same city
        $city = self::detect_city($lat, $lng);
        if ($city) {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if ($central) {
                $options['standard'] = [
                    'delivery_type'  => self::TYPE_STANDARD,
                    'warehouse_code' => $central['warehouse_code'],
                    'warehouse_name' => is_rtl() ? ($central['display_name_ar'] ?: $central['display_name_en']) : ($central['display_name_en'] ?: $central['display_name_ar']),
                    'estimated_time' => __('خلال 24 ساعة', 'zooboxi'),
                    'fee'            => (float) get_option('zooboxi_standard_fee', 10),
                ];
            }
        }

        // 3. Shipping — always available from main hub
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        if ($hub) {
            $options['shipping'] = [
                'delivery_type'  => self::TYPE_SHIPPING,
                'warehouse_code' => $hub['warehouse_code'],
                'warehouse_name' => is_rtl() ? ($hub['display_name_ar'] ?: $hub['display_name_en']) : ($hub['display_name_en'] ?: $hub['display_name_ar']),
                'estimated_time' => __('2-4 أيام عمل', 'zooboxi'),
                'fee'            => (float) get_option('zooboxi_shipping_fee', 25),
            ];
        }

        // 4. Pickup locations
        $pickups = Zooboxi_Warehouse_Manager::get_pickup_locations($lat, $lng);
        foreach (array_slice($pickups, 0, 5) as $p) {
            $wh = $p['warehouse'];
            $options['pickup'][] = [
                'delivery_type'  => self::TYPE_PICKUP,
                'warehouse_code' => $wh['warehouse_code'],
                'warehouse_name' => is_rtl() ? ($wh['display_name_ar'] ?: $wh['display_name_en']) : ($wh['display_name_en'] ?: $wh['display_name_ar']),
                'address'        => is_rtl() ? ($wh['address_ar'] ?: $wh['address_en']) : ($wh['address_en'] ?: $wh['address_ar']),
                'distance_km'    => $p['distance'],
                'phone'          => $wh['phone'] ?? '',
                'fee'            => 0,
            ];
        }

        // Check free-shipping threshold
        $freeMin = (float) get_option('zooboxi_free_shipping_min', 200);
        $cartTotal = self::calculate_cart_total($cartItems);
        if ($cartTotal >= $freeMin) {
            foreach (['express', 'standard', 'shipping'] as $key) {
                if ($options[$key]) $options[$key]['fee'] = 0;
            }
        }

        return $options;
    }

    /**
     * Determine which warehouse should fulfill an order based on delivery type.
     */
    public static function determine_fulfillment_warehouse(string $deliveryType, float $lat, float $lng): ?string
    {
        return match ($deliveryType) {
            self::TYPE_EXPRESS => Zooboxi_Warehouse_Manager::find_nearest($lat, $lng)['warehouse']['warehouse_code'] ?? null,
            self::TYPE_STANDARD => Zooboxi_Warehouse_Manager::find_central(self::detect_city($lat, $lng))['warehouse_code'] ?? null,
            self::TYPE_SHIPPING => Zooboxi_Warehouse_Manager::get_main_hub()['warehouse_code'] ?? null,
            default => null,
        };
    }

    /**
     * Simple city detection — match lat/lng to nearest warehouse's city.
     */
    private static function detect_city(float $lat, float $lng): ?string
    {
        $nearest = Zooboxi_Warehouse_Manager::find_nearest($lat, $lng);
        return $nearest ? ($nearest['warehouse']['city'] ?? null) : null;
    }

    private static function calculate_cart_total(array $items): float
    {
        $total = 0;
        foreach ($items as $item) {
            $total += ($item['unit_price'] ?? 0) * ($item['quantity'] ?? 1);
        }
        return $total;
    }
}
