<?php
/**
 * Geographic Helper — Haversine distance + point-in-polygon for express zones.
 */
class Zooboxi_Geo_Helper
{
    /**
     * Calculate distance between two GPS points using Haversine (km).
     */
    public static function distance(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371; // km

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLng / 2) * sin($dLng / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadius * $c;
    }

    /**
     * Check if a point is inside a GeoJSON Polygon using ray-casting algorithm.
     *
     * @param float  $lat  Customer latitude
     * @param float  $lng  Customer longitude
     * @param array  $polygon GeoJSON-style polygon: {"type":"Polygon","coordinates":[[[lng,lat],...]]}
     * @return bool
     */
    public static function point_in_polygon(float $lat, float $lng, array $polygon): bool
    {
        // GeoJSON uses [longitude, latitude] order
        $coords = $polygon['coordinates'][0] ?? [];
        if (count($coords) < 3) return false;

        return self::ray_cast($lng, $lat, $coords);
    }

    /**
     * Ray-casting algorithm for point-in-polygon.
     * Coordinates are in [lng, lat] format (GeoJSON standard).
     */
    private static function ray_cast(float $x, float $y, array $polygon): bool
    {
        $n = count($polygon);
        $inside = false;

        for ($i = 0, $j = $n - 1; $i < $n; $j = $i++) {
            $xi = (float) $polygon[$i][0]; // lng
            $yi = (float) $polygon[$i][1]; // lat
            $xj = (float) $polygon[$j][0]; // lng
            $yj = (float) $polygon[$j][1]; // lat

            $intersect = (($yi > $y) !== ($yj > $y))
                && ($x < ($xj - $xi) * ($y - $yi) / ($yj - $yi) + $xi);

            if ($intersect) {
                $inside = !$inside;
            }
        }

        return $inside;
    }

    /**
     * Check if a point is within a circular radius of a center point.
     *
     * @param float $lat      Customer latitude
     * @param float $lng      Customer longitude
     * @param float $centerLat Warehouse latitude
     * @param float $centerLng Warehouse longitude
     * @param float $radiusKm  Radius in kilometers
     * @return bool
     */
    public static function is_within_radius(float $lat, float $lng, float $centerLat, float $centerLng, float $radiusKm): bool
    {
        return self::distance($lat, $lng, $centerLat, $centerLng) <= $radiusKm;
    }
}
