<?php
/**
 * Geographic helper — Haversine distance calculation.
 */
class Zooboxi_Geo_Helper
{
    private const EARTH_RADIUS_KM = 6371;

    /**
     * Calculate distance between two GPS points in kilometres.
     */
    public static function distance(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
           + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return self::EARTH_RADIUS_KM * $c;
    }

    /**
     * Check if a point is within a radius of another point.
     */
    public static function is_within_radius(float $lat1, float $lng1, float $lat2, float $lng2, float $radiusKm): bool
    {
        return self::distance($lat1, $lng1, $lat2, $lng2) <= $radiusKm;
    }
}
