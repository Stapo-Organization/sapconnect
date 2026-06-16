<?php

namespace App\Services\Intelligence;

use Carbon\Carbon;

/**
 * Pure demand & on-hand reconstruction helpers shared by the item-level
 * (intelligence:build-products) and per-branch (intelligence:build-branch-products)
 * intelligence builders.
 *
 * No SAP calls, no DB writes — just the velocity/health/stockout math, so both
 * the global rollup and the per-warehouse builder tell a genuinely DEAD product
 * from a STARVED one (a good seller that ran out) exactly the same way.
 */
class DemandReconstructionService
{
    public const HERO_PER_DAY = 3.33;       // >= ~100/month
    public const COVER_TARGET_DAYS = 180;

    /** Build $map[item_code][dayOffset] = signed quantity (non-negative "days ago" offset). */
    public function dayMap($rows, Carbon $today): array
    {
        $map = [];
        foreach ($rows as $r) {
            // Carbon 3 diffInDays is signed; we want a non-negative offset.
            $off = (int) abs($today->diffInDays(Carbon::parse($r->doc_date)));
            $map[$r->item_code][$off] = ($map[$r->item_code][$off] ?? 0) + (float) $r->q;
        }
        return $map;
    }

    /**
     * Walk the last $window days backward from current stock, counting days on-hand>0.
     * delta(day) = arrivals(+) − outflow(−). on_hand(prev) = on_hand − delta(day).
     *
     * @return array{0:int,1:float}  [in_stock_days, in_stock_rate]
     */
    public function reconstruct(float $stock, array $arr, array $out, int $window): array
    {
        if (empty($arr) && empty($out)) {
            // No movements in the window → assume on-hand was stable.
            return [$stock > 0 ? $window : 0, $stock > 0 ? 1.0 : 0.0];
        }
        $oh = $stock;
        $inStock = 0;
        for ($off = 0; $off < $window; $off++) {
            if ($oh > 0) {
                $inStock++;
            }
            $delta = ($arr[$off] ?? 0) - ($out[$off] ?? 0);
            $oh -= $delta;
        }
        return [$inStock, round($inStock / $window, 4)];
    }

    public function classifyHealth(float $stock, float $s90, float $s365, ?float $cover, float $inStockRate, float $vTrue, int $coverTarget = self::COVER_TARGET_DAYS): string
    {
        if ($stock <= 0) {
            return ($s365 > 0 || $s90 > 0) ? 'stockout' : 'dead';
        }
        // Good seller that was out of stock much of the window → reorder, don't clear.
        if ($inStockRate < 0.7 && $vTrue >= 0.5) {
            return 'starved';
        }
        if ($s365 <= 0) {
            return 'dead';
        }
        if ($cover !== null && $cover > $coverTarget) {
            return 'overstock';
        }
        if ($cover !== null && $cover < 30) {
            return 'low';
        }
        return 'healthy';
    }

    public function classifyDemand(float $s90, float $s365, ?string $lastSale, ?string $created): string
    {
        if ($s365 <= 0) {
            // Never sold: NEW if recently created, else DEAD.
            if ($created && Carbon::parse($created)->gt(Carbon::today()->subDays(60))) {
                return 'new';
            }
            return 'dead';
        }
        if ($s90 >= 30) {
            return 'fast';
        }
        return 'intermittent';
    }

    public function retailPrice($pricesJson): ?float
    {
        $arr = json_decode((string) $pricesJson, true);
        if (!is_array($arr)) {
            return null;
        }
        $fallback = null;
        foreach ($arr as $row) {
            if (!is_array($row)) {
                continue;
            }
            $p = $row['Price'] ?? $row['price'] ?? null;
            if ($p === null) {
                continue;
            }
            $fallback = $fallback ?? (float) $p;
            if ((int) ($row['PriceList'] ?? $row['priceList'] ?? 0) === 1) {
                return (float) $p;
            }
        }
        return $fallback;
    }
}
