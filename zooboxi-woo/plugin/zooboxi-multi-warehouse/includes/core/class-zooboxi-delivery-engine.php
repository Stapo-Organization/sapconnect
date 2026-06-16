<?php
/**
 * Smart Delivery Engine — determines the best delivery option
 * based on customer GPS location and warehouse proximity.
 * Enhanced with per-product delivery detection and cart analysis.
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
    public static function detect_options(float $lat, float $lng, array $cartItems = [], ?string $customerCity = null): array
    {
        $options = [
            'express'  => null,
            'standard' => null,
            'shipping' => null,
            'pickup'   => [],
        ];

        // 1. Express — nearest express-enabled warehouse within polygon/radius + working hours
        $expressWarehouses = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
        if (!empty($expressWarehouses)) {
            $nearest = $expressWarehouses[0];
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

        // 2. Standard — central warehouse in SAME city (use actual geocoded city, not nearest warehouse)
        $city = $customerCity ?: self::detect_city($lat, $lng);
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
                'estimated_time' => __('4-5 أيام عمل', 'zooboxi'),
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
     * Determine the fastest delivery option for a SINGLE product.
     * Used on product cards and product detail pages.
     *
     * @param int   $productId WooCommerce product ID
     * @param float $lat       Customer latitude
     * @param float $lng       Customer longitude
     * @return array [
     *   'type'           => 'express'|'same_day'|'shipping',
     *   'label'          => 'خلال ساعتين',
     *   'warehouse_code' => 'RUH002',
     *   'warehouse_name' => 'فرع الربيع',
     *   'stock_qty'      => 25,
     *   'fee'            => 15,
     *   'is_express_hours' => true,
     * ]
     */
    public static function detect_product_delivery(int $productId, float $lat, float $lng, ?string $customerCity = null, int $quantity = 1): array
    {
        $quantity = max(1, $quantity);
        $warehouseStock = Zooboxi_Stock_Manager::get_warehouse_stock($productId);

        if (empty($warehouseStock)) {
            return self::make_delivery_result(self::TYPE_SHIPPING, $lat, $lng);
        }

        // Build lookup: warehouse_code => stock_qty
        $stockMap = [];
        foreach ($warehouseStock as $ws) {
            $code = $ws['warehouse_code'] ?? '';
            $qty = (float) ($ws['in_stock'] ?? 0);
            if ($code && $qty > 0) {
                $stockMap[$code] = $qty;
            }
        }

        if (empty($stockMap)) {
            return self::make_delivery_result(self::TYPE_SHIPPING, $lat, $lng);
        }

        // 1. Check express — find express warehouses in customer's zone that have this product
        $expressWarehouses = Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng);
        foreach ($expressWarehouses as $ew) {
            $code = $ew['warehouse']['warehouse_code'];
            // Quantity-aware: the branch must hold the FULL requested quantity for express.
            if (isset($stockMap[$code]) && $stockMap[$code] >= $quantity) {
                $wh = $ew['warehouse'];
                return [
                    'type'             => self::TYPE_EXPRESS,
                    'label'            => __('خلال ساعتين', 'zooboxi'),
                    'warehouse_code'   => $code,
                    'warehouse_name'   => is_rtl() ? ($wh['display_name_ar'] ?: $wh['display_name_en']) : ($wh['display_name_en'] ?: $wh['display_name_ar']),
                    'stock_qty'        => (int) $stockMap[$code],
                    'fee'              => (float) get_option('zooboxi_express_fee', 15),
                    'is_express_hours' => true,
                    'distance_km'      => $ew['distance'],
                ];
            }
        }

        // 2. Check same-city (standard 24H) — use actual customer city
        $city = $customerCity ?: self::detect_city($lat, $lng);
        if ($city) {
            $central = Zooboxi_Warehouse_Manager::find_central($city);
            if ($central && isset($stockMap[$central['warehouse_code']]) && $stockMap[$central['warehouse_code']] >= $quantity) {
                return [
                    'type'             => self::TYPE_STANDARD,
                    'label'            => __('خلال 24 ساعة', 'zooboxi'),
                    'warehouse_code'   => $central['warehouse_code'],
                    'warehouse_name'   => is_rtl() ? ($central['display_name_ar'] ?: $central['display_name_en']) : ($central['display_name_en'] ?: $central['display_name_ar']),
                    'stock_qty'        => (int) $stockMap[$central['warehouse_code']],
                    'fee'              => (float) get_option('zooboxi_standard_fee', 10),
                    'is_express_hours' => false,
                    'distance_km'      => null,
                ];
            }
        }

        // 3. Fallback to national shipping
        return self::make_delivery_result(self::TYPE_SHIPPING, $lat, $lng);
    }

    /**
     * Analyze entire cart: classify each item's delivery type and determine overall.
     * Uses Option A: slowest item dictates overall delivery.
     *
     * @param array $cartItems WC cart items
     * @param float $lat
     * @param float $lng
     * @return array [
     *   'express_items'     => [ [cart_key, product_id, delivery_info], ... ],
     *   'standard_items'    => [ ... ],
     *   'shipping_items'    => [ ... ],
     *   'overall_type'      => 'express'|'same_day'|'shipping',
     *   'overall_label'     => 'خلال ساعتين',
     *   'express_warehouse' => 'RUH002' | null,
     *   'all_express'       => true|false,
     *   'summary'           => 'جميع منتجاتك متاحة للتوصيل السريع!',
     * ]
     */
    public static function analyze_cart_delivery(array $cartItems, float $lat, float $lng): array
    {
        $result = [
            'express_items'     => [],
            'standard_items'    => [],
            'shipping_items'    => [],
            'overall_type'      => self::TYPE_EXPRESS,
            'overall_label'     => __('خلال ساعتين', 'zooboxi'),
            'express_warehouse' => null,
            'all_express'       => true,
            'summary'           => '',
        ];

        if (empty($cartItems) || (!$lat && !$lng)) {
            $result['overall_type'] = self::TYPE_SHIPPING;
            $result['overall_label'] = __('4-5 أيام عمل', 'zooboxi');
            $result['all_express'] = false;
            return $result;
        }

        // Priority ranking for delivery types (lower = faster)
        $priority = [
            self::TYPE_EXPRESS  => 1,
            self::TYPE_STANDARD => 2,
            self::TYPE_SHIPPING => 3,
        ];

        $slowest = 0; // Track slowest item

        foreach ($cartItems as $cartKey => $item) {
            $productId = $item['product_id'] ?? ($item['id'] ?? 0);
            if (!$productId) continue;

            $delivery = self::detect_product_delivery($productId, $lat, $lng, null, (int) ($item['quantity'] ?? 1));
            $type = $delivery['type'];

            $entry = [
                'cart_key'   => $cartKey,
                'product_id' => $productId,
                'delivery'   => $delivery,
            ];

            switch ($type) {
                case self::TYPE_EXPRESS:
                    $result['express_items'][] = $entry;
                    if (!$result['express_warehouse']) {
                        $result['express_warehouse'] = $delivery['warehouse_code'];
                    }
                    break;
                case self::TYPE_STANDARD:
                    $result['standard_items'][] = $entry;
                    $result['all_express'] = false;
                    break;
                default:
                    $result['shipping_items'][] = $entry;
                    $result['all_express'] = false;
                    break;
            }

            $itemPriority = $priority[$type] ?? 3;
            if ($itemPriority > $slowest) {
                $slowest = $itemPriority;
                $result['overall_type'] = $type;
            }
        }

        // Set overall label
        $result['overall_label'] = match ($result['overall_type']) {
            self::TYPE_EXPRESS  => __('خلال ساعتين', 'zooboxi'),
            self::TYPE_STANDARD => __('خلال 24 ساعة', 'zooboxi'),
            self::TYPE_SHIPPING => __('4-5 أيام عمل', 'zooboxi'),
            default             => __('4-5 أيام عمل', 'zooboxi'),
        };

        // Generate summary message
        $expressCount = count($result['express_items']);
        $totalCount = $expressCount + count($result['standard_items']) + count($result['shipping_items']);

        if ($result['all_express'] && $expressCount > 0) {
            $result['summary'] = __('🎉 جميع منتجاتك متاحة للتوصيل السريع!', 'zooboxi');
        } elseif ($expressCount > 0 && !$result['all_express']) {
            $normalCount = $totalCount - $expressCount;
            $result['summary'] = sprintf(
                __('⚡ %d منتج متاح للتوصيل السريع، %d منتج يتطلب شحن عادي. سيتم توصيل الطلب كاملاً خلال %s', 'zooboxi'),
                $expressCount,
                $normalCount,
                $result['overall_label']
            );
        } else {
            $result['summary'] = sprintf(
                __('📦 سيتم توصيل طلبك خلال %s', 'zooboxi'),
                $result['overall_label']
            );
        }

        return $result;
    }

    /**
     * Determine which warehouse should fulfill an order based on delivery type.
     */
    public static function determine_fulfillment_warehouse(string $deliveryType, float $lat, float $lng): ?string
    {
        return match ($deliveryType) {
            self::TYPE_EXPRESS => Zooboxi_Warehouse_Manager::find_express_warehouses($lat, $lng)[0]['warehouse']['warehouse_code'] ?? null,
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

    /**
     * Build a default delivery result for fallback scenarios.
     */
    private static function make_delivery_result(string $type, float $lat, float $lng): array
    {
        $hub = Zooboxi_Warehouse_Manager::get_main_hub();
        $city = self::detect_city($lat, $lng);
        $central = $city ? Zooboxi_Warehouse_Manager::find_central($city) : null;

        return match ($type) {
            self::TYPE_STANDARD => [
                'type'             => self::TYPE_STANDARD,
                'label'            => __('خلال 24 ساعة', 'zooboxi'),
                'warehouse_code'   => $central['warehouse_code'] ?? '',
                'warehouse_name'   => $central ? (is_rtl() ? ($central['display_name_ar'] ?: $central['display_name_en']) : ($central['display_name_en'] ?: $central['display_name_ar'])) : '',
                'stock_qty'        => 0,
                'fee'              => (float) get_option('zooboxi_standard_fee', 10),
                'is_express_hours' => false,
                'distance_km'      => null,
            ],
            default => [
                'type'             => self::TYPE_SHIPPING,
                'label'            => __('4-5 أيام عمل', 'zooboxi'),
                'warehouse_code'   => $hub['warehouse_code'] ?? '',
                'warehouse_name'   => $hub ? (is_rtl() ? ($hub['display_name_ar'] ?: $hub['display_name_en']) : ($hub['display_name_en'] ?: $hub['display_name_ar'])) : '',
                'stock_qty'        => 0,
                'fee'              => (float) get_option('zooboxi_shipping_fee', 25),
                'is_express_hours' => false,
                'distance_km'      => null,
            ],
        };
    }
}
