<?php

namespace App\Console\Commands;

use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Builds the channel-safe clearance queue (DB-only). Reads product_intelligence,
 * keeps only OVERSTOCK + DEAD (starved/stockout are reorder, never clearance),
 * ranks by Liquidation Priority Score, and sets a floor that defaults to the retail
 * price — so the store NEVER undercuts Muntajat's wholesale customers. Discounts are
 * suggest-only (recommended_discount_pct=0 by default) and owner-approved; the actual
 * clearance lever is merchandising visibility, not a price break.
 */
class PlanClearance extends Command
{
    protected $signature = 'intelligence:plan-clearance';
    protected $description = 'Build channel-safe clearance_campaigns (LPS ranking, retail-protecting floors) — DB only.';

    private const COVER_TARGET_DAYS = 180;
    private const WHOLESALE_FLOOR_FACTOR = 1.0; // 1.0 = floor at retail (no market break)
    private const MIN_MARKUP_OVER_COST = 0.10;
    private const SENTINEL_STAGNATION = 999;
    private const SENTINEL_EXCESS_COVER = 99999;

    public function handle(): int
    {
        DB::connection()->disableQueryLog();
        $today = Carbon::today();
        $this->info('Planning channel-safe clearance...');

        $candidates = DB::table('product_intelligence')
            ->where('warehouse_code', '')
            ->whereIn('health_status', ['overstock', 'dead'])
            ->get([
                'item_code', 'health_status', 'is_never_sold', 'capital_at_risk_sar',
                'days_of_cover', 'last_sale_date', 'unit_retail_sar', 'unit_cost_sar',
            ]);

        if ($candidates->isEmpty()) {
            $this->warn('No clearance candidates. Run intelligence:build-products first.');
            return self::SUCCESS;
        }

        // Confidence flags from the one cost service.
        $confidence = DB::table('product_costs')->pluck('cost_confidence', 'item_code');

        // Refresh suggestions, but never clobber owner-approved (active/ended) campaigns.
        DB::table('clearance_campaigns')->where('status', 'suggested')->delete();
        $locked = DB::table('clearance_campaigns')->pluck('item_code')->flip();

        // Collect metric arrays for percentile ranking.
        $caps = $excesses = $stags = [];
        $rowsData = [];
        foreach ($candidates as $c) {
            if (isset($locked[$c->item_code])) {
                continue; // owner already decided on this item
            }
            $excess = $c->days_of_cover === null
                ? self::SENTINEL_EXCESS_COVER
                : max(0, (float) $c->days_of_cover - self::COVER_TARGET_DAYS);
            $stag = $c->last_sale_date
                ? $today->diffInDays(Carbon::parse($c->last_sale_date))
                : self::SENTINEL_STAGNATION;
            $stag = (int) abs($stag);

            $caps[] = (float) $c->capital_at_risk_sar;
            $excesses[] = $excess;
            $stags[] = $stag;
            $rowsData[] = ['c' => $c, 'excess' => $excess, 'stag' => $stag];
        }
        sort($caps);
        sort($excesses);
        sort($stags);
        $n = count($rowsData);

        $now = now();
        $rows = [];
        $count = 0;
        foreach ($rowsData as $d) {
            $c = $d['c'];
            $zCap = $this->pct($caps, (float) $c->capital_at_risk_sar, $n);
            $zExcess = $this->pct($excesses, $d['excess'], $n);
            $zStag = $this->pct($stags, $d['stag'], $n);

            $reason = $c->is_never_sold ? 'never_sold' : ($c->health_status === 'dead' ? 'dead' : 'overstock');
            $lps = 100 * (0.40 * $zCap + 0.35 * $zExcess + 0.25 * $zStag)
                 + (in_array($reason, ['dead', 'never_sold'], true) ? 15 : 0);

            $retail = $c->unit_retail_sar !== null ? (float) $c->unit_retail_sar : null;
            $cost = $c->unit_cost_sar !== null ? (float) $c->unit_cost_sar : null;

            // Floor protects the wholesale channel: never below retail, and never below cost+markup.
            $costFloor = $cost !== null ? $cost * (1 + self::MIN_MARKUP_OVER_COST) : 0;
            $retailFloor = $retail !== null ? $retail * self::WHOLESALE_FLOOR_FACTOR : 0;
            $floor = max($costFloor, $retailFloor) ?: null;

            $rows[] = [
                'item_code' => $c->item_code,
                'reason' => $reason,
                'lps' => round(min($lps, 115), 2),
                'capital_tied_sar' => round((float) $c->capital_at_risk_sar, 2),
                'days_of_cover' => $c->days_of_cover,
                'stagnation_days' => $d['stag'],
                'retail_price' => $retail,
                'cost_proxy' => $cost,
                'cost_confidence' => $confidence[$c->item_code] ?? null,
                'floor_price' => $floor,
                'recommended_discount_pct' => 0, // channel-safe default; owner enables per item/brand
                'recommended_sale_price' => $retail, // = retail until owner approves a markdown
                'status' => 'suggested',
                'computed_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];

            if (count($rows) >= 500) {
                $this->flush($rows);
                $count += count($rows);
                $rows = [];
            }
        }
        if ($rows) {
            $this->flush($rows);
            $count += count($rows);
        }

        $this->info("Planned clearance for {$count} items (suggest-only, retail-protected floors).");
        return self::SUCCESS;
    }

    private function pct(array $sorted, float $v, int $n): float
    {
        if ($n === 0) {
            return 0.0;
        }
        $lo = 0;
        $hi = count($sorted);
        while ($lo < $hi) {
            $mid = intdiv($lo + $hi, 2);
            if ($sorted[$mid] <= $v) {
                $lo = $mid + 1;
            } else {
                $hi = $mid;
            }
        }
        return $lo / $n;
    }

    private function flush(array $rows): void
    {
        // Fresh suggestions only (locked/owner rows were excluded upstream).
        DB::table('clearance_campaigns')->insert($rows);
    }
}
