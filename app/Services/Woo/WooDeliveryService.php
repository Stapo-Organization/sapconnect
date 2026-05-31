<?php

namespace App\Services\Woo;

use App\Models\ZooboxiWarehouse;
use App\Models\WarehouseItemStock;

/**
 * Smart delivery service for Zooboxi.
 * Determines the best warehouse and delivery tier based on customer GPS location.
 *
 * Delivery Tiers:
 *  1. Express (≤2 hours)   — Customer within express_radius_km of a warehouse
 *  2. Same-Day (≤24 hours) — Central warehouse exists in customer's city
 *  3. Shipping (2-4 days)  — National shipping from the main hub
 *  4. Pickup (free)        — Customer collects from a branch
 */
class WooDeliveryService
{
    /**
     * Determine all available delivery options for a customer location.
     *
     * @param float $lat Customer latitude
     * @param float $lng Customer longitude
     * @param array $cartItems Array of ['item_code' => string, 'quantity' => float]
     * @return array
     */
    public function detectDeliveryOptions(float $lat, float $lng, array $cartItems = []): array
    {
        $warehouses = ZooboxiWarehouse::active()->get();
        $options = [];

        // 1. Check Express delivery
        $expressWarehouse = $this->findExpressWarehouse($warehouses, $lat, $lng, $cartItems);
        if ($expressWarehouse) {
            $options[] = [
                'type' => 'express',
                'label_ar' => '🚀 توصيل سريع (خلال ساعتين)',
                'label_en' => '🚀 Express Delivery (within 2 hours)',
                'estimated_time' => '2 hours',
                'fee' => config('services.woo.express_fee', 15),
                'warehouse_code' => $expressWarehouse['warehouse']->warehouse_code,
                'warehouse_name' => $expressWarehouse['warehouse']->display_name_ar,
                'distance_km' => $expressWarehouse['distance'],
            ];
        }

        // 2. Check Same-Day delivery
        $city = $this->detectCity($lat, $lng, $warehouses);
        $centralWarehouse = $this->findCentralWarehouse($warehouses, $city, $cartItems);
        if ($centralWarehouse) {
            $options[] = [
                'type' => 'same_day',
                'label_ar' => '📦 توصيل عادي (خلال 24 ساعة)',
                'label_en' => '📦 Standard Delivery (within 24 hours)',
                'estimated_time' => '24 hours',
                'fee' => config('services.woo.standard_fee', 10),
                'warehouse_code' => $centralWarehouse->warehouse_code,
                'warehouse_name' => $centralWarehouse->display_name_ar,
            ];
        }

        // 3. National Shipping (always available)
        $mainHub = $warehouses->where('is_main_hub', true)->first();
        if ($mainHub) {
            $options[] = [
                'type' => 'shipping',
                'label_ar' => '🚚 شحن (2-4 أيام عمل)',
                'label_en' => '🚚 Shipping (2-4 business days)',
                'estimated_time' => '2-4 business days',
                'fee' => config('services.woo.shipping_fee', 25),
                'warehouse_code' => $mainHub->warehouse_code,
                'warehouse_name' => $mainHub->display_name_ar,
            ];
        }

        // 4. Pickup locations
        $pickupLocations = $this->getPickupLocations($warehouses, $lat, $lng, $cartItems);
        foreach ($pickupLocations as $pickup) {
            $options[] = [
                'type' => 'pickup',
                'label_ar' => sprintf('🏬 استلام من %s (%.1f كم)', $pickup['warehouse']->display_name_ar, $pickup['distance']),
                'label_en' => sprintf('🏬 Pickup from %s (%.1f km)', $pickup['warehouse']->display_name_en ?? $pickup['warehouse']->display_name_ar, $pickup['distance']),
                'estimated_time' => 'ready in 1-2 hours',
                'fee' => 0,
                'warehouse_code' => $pickup['warehouse']->warehouse_code,
                'warehouse_name' => $pickup['warehouse']->display_name_ar,
                'address' => $pickup['warehouse']->address_ar,
                'distance_km' => $pickup['distance'],
                'is_open' => $pickup['warehouse']->isOpenNow(),
                'has_all_items' => $pickup['has_all_items'],
            ];
        }

        return [
            'customer_city' => $city,
            'options' => $options,
            'recommended' => !empty($options) ? $options[0]['type'] : 'shipping',
        ];
    }

    /**
     * Find the nearest warehouse that supports express delivery.
     */
    private function findExpressWarehouse($warehouses, float $lat, float $lng, array $cartItems): ?array
    {
        $candidates = [];

        foreach ($warehouses as $wh) {
            $distance = $wh->distanceTo($lat, $lng);

            if ($distance <= $wh->express_radius_km) {
                $hasItems = empty($cartItems) || $wh->hasAllItems($cartItems);
                if ($hasItems) {
                    $candidates[] = [
                        'warehouse' => $wh,
                        'distance' => $distance,
                    ];
                }
            }
        }

        if (empty($candidates)) {
            return null;
        }

        // Return the nearest
        usort($candidates, fn($a, $b) => $a['distance'] <=> $b['distance']);
        return $candidates[0];
    }

    /**
     * Find the central warehouse for a city.
     */
    private function findCentralWarehouse($warehouses, ?string $city, array $cartItems): ?ZooboxiWarehouse
    {
        if (!$city) {
            return null;
        }

        $central = $warehouses
            ->where('city', $city)
            ->where('is_central', true)
            ->first();

        if (!$central) {
            return null;
        }

        if (!empty($cartItems) && !$central->hasAllItems($cartItems)) {
            return null;
        }

        return $central;
    }

    /**
     * Get available pickup locations sorted by distance.
     */
    private function getPickupLocations($warehouses, float $lat, float $lng, array $cartItems): array
    {
        $locations = [];

        foreach ($warehouses->where('is_pickup_enabled', true) as $wh) {
            $distance = $wh->distanceTo($lat, $lng);
            $hasAllItems = empty($cartItems) || $wh->hasAllItems($cartItems);

            $locations[] = [
                'warehouse' => $wh,
                'distance' => $distance,
                'has_all_items' => $hasAllItems,
            ];
        }

        usort($locations, fn($a, $b) => $a['distance'] <=> $b['distance']);

        return array_slice($locations, 0, 5); // Max 5 pickup locations
    }

    /**
     * Detect the city based on GPS coordinates.
     * Uses nearest warehouse city as a heuristic (avoids external geocoding API dependency).
     */
    private function detectCity(float $lat, float $lng, $warehouses): ?string
    {
        $nearest = null;
        $minDistance = PHP_FLOAT_MAX;

        foreach ($warehouses as $wh) {
            $distance = $wh->distanceTo($lat, $lng);
            if ($distance < $minDistance) {
                $minDistance = $distance;
                $nearest = $wh;
            }
        }

        // If the nearest warehouse is within 100km, use its city
        if ($nearest && $minDistance <= 100) {
            return $nearest->city;
        }

        return null;
    }

    /**
     * Determine the best warehouse for fulfilling an order.
     */
    public function determineFulfillmentWarehouse(string $deliveryType, float $lat, float $lng, array $cartItems): ?string
    {
        $warehouses = ZooboxiWarehouse::active()->get();

        return match ($deliveryType) {
            'express' => $this->findExpressWarehouse($warehouses, $lat, $lng, $cartItems)['warehouse']->warehouse_code ?? null,
            'same_day' => $this->findCentralWarehouse($warehouses, $this->detectCity($lat, $lng, $warehouses), $cartItems)?->warehouse_code,
            'shipping' => $warehouses->where('is_main_hub', true)->first()?->warehouse_code,
            'pickup' => null, // Warehouse is chosen by the customer
            default => $warehouses->where('is_main_hub', true)->first()?->warehouse_code,
        };
    }
}
