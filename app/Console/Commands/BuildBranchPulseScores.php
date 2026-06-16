<?php

namespace App\Console\Commands;

use App\Models\ZooboxiSetting;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Per-branch "Showroom Pulse" score builder (DB-ONLY — never calls SAP).
 *
 * Reads branch_product_intelligence (built first by intelligence:build-branch-products),
 * this warehouse's C0000001 baskets and its ABC count-variance, and writes one row
 * per warehouse into `branch_pulse_scores`: the four vital signs, the composite
 * score (0-100), the cross-branch rank, and the headline money figures behind the
 * 🔴/🟡 levers of نبض المعرض.
 *
 * Every vital is a RATE (0-100) so branches of any size rank fairly. A vital with
 * no data (e.g. count accuracy before the first cycle count) is null and dropped
 * from the blend, with the remaining weights renormalized — so a branch is never
 * punished for a signal it could not have produced yet.
 */
class BuildBranchPulseScores extends Command
{
    protected $signature = 'intelligence:build-branch-pulse {--warehouse= : Limit to a single warehouse code}';
    protected $description = 'Build branch_pulse_scores (4 vital signs + composite + cross-branch rank) — DB only.';

    /** Vital weights (owner-tunable via ZooboxiSetting → pulse_w_*). */
    private array $weights = [
        'hero' => 0.35, 'capital' => 0.30, 'basket' => 0.20, 'accuracy' => 0.15,
    ];

    public function handle(): int
    {
        DB::connection()->disableQueryLog();
        $this->loadWeights();
        $basketTarget = (float) (ZooboxiSetting::get('pulse_basket_target', 3.0) ?: 3.0);
        $now = now();

        $warehouses = DB::table('branch_product_intelligence')
            ->select('warehouse_code')->distinct()
            ->when($this->option('warehouse'), fn ($q) => $q->where('warehouse_code', $this->option('warehouse')))
            ->pluck('warehouse_code');

        $this->info("Building branch_pulse_scores for {$warehouses->count()} warehouse(s)...");

        $results = [];
        foreach ($warehouses as $wh) {
            $results[$wh] = $this->computeWarehouse($wh, $basketTarget);
        }

        // Cross-branch ranking (highest score = rank 1).
        $ranked = collect($results)->sortByDesc(fn ($r) => $r['score'])->keys()->values();
        $total = $ranked->count();

        foreach ($results as $wh => $r) {
            $prev = DB::table('branch_pulse_scores')->where('warehouse_code', $wh)->value('score');
            DB::table('branch_pulse_scores')->upsert([[
                'warehouse_code' => $wh,
                'score' => $r['score'],
                'score_prev' => $prev, // last run's score → drives the trend arrow
                'vital_hero_availability' => $r['hero'],
                'vital_capital_efficiency' => $r['capital'],
                'vital_basket_size' => $r['basket'],
                'vital_count_accuracy' => $r['accuracy'],
                'basket_items_per_invoice' => $r['basket_raw'],
                'bleeding_monthly_sar' => $r['bleeding'],
                'trapped_capital_sar' => $r['trapped'],
                'rank' => $ranked->search($wh) + 1,
                'total_branches' => $total,
                'computed_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]], ['warehouse_code'], [
                'score', 'score_prev', 'vital_hero_availability', 'vital_capital_efficiency',
                'vital_basket_size', 'vital_count_accuracy', 'basket_items_per_invoice',
                'bleeding_monthly_sar', 'trapped_capital_sar', 'rank', 'total_branches',
                'computed_at', 'updated_at',
            ]);
            $this->line("  {$wh}: score {$r['score']} (rank " . ($ranked->search($wh) + 1) . "/{$total})");
        }

        $this->info("Built branch_pulse_scores for {$total} warehouse(s).");
        return self::SUCCESS;
    }

    /** @return array<string,mixed> */
    private function computeWarehouse(string $wh, float $basketTarget): array
    {
        $items = DB::table('branch_product_intelligence')
            ->where('warehouse_code', $wh)
            ->get([
                'current_stock', 'unit_cost_sar', 'unit_retail_sar', 'capital_at_risk_sar',
                'lost_sales_monthly', 'velocity_blended', 'is_hero', 'demand_class',
            ]);

        $heroVelTotal = 0.0;   // velocity-weighted denominator for hero availability
        $heroVelInStock = 0.0;
        $capTotal = 0.0;       // total inventory capital
        $capRisk = 0.0;        // capital in dead/overstock
        $bleeding = 0.0;       // lost revenue / month (🔴)
        $trapped = 0.0;        // dead + overstock capital (🟡)

        foreach ($items as $it) {
            $vel = (float) $it->velocity_blended;
            $stock = (float) $it->current_stock;

            // Heroes = is_hero OR fast movers; a fast seller out of stock hurts most.
            if (($it->is_hero || $it->demand_class === 'fast') && $vel > 0) {
                $heroVelTotal += $vel;
                if ($stock > 0) {
                    $heroVelInStock += $vel;
                }
            }

            $unitVal = $it->unit_cost_sar !== null
                ? (float) $it->unit_cost_sar
                : ($it->unit_retail_sar !== null ? (float) $it->unit_retail_sar * 0.6 : 0.0);
            $capTotal += $stock * $unitVal;
            $capRisk += (float) $it->capital_at_risk_sar;

            $unitRevenue = $it->unit_retail_sar !== null
                ? (float) $it->unit_retail_sar
                : ($it->unit_cost_sar !== null ? (float) $it->unit_cost_sar / 0.6 : 0.0);
            $bleeding += (float) $it->lost_sales_monthly * $unitRevenue;
            $trapped += (float) $it->capital_at_risk_sar;
        }

        // Vital 1 — hero availability (no heroes → nothing to protect → 100).
        $hero = $heroVelTotal > 0 ? round($heroVelInStock / $heroVelTotal * 100, 2) : 100.0;

        // Vital 2 — capital efficiency (share of capital NOT trapped).
        $capital = $capTotal > 0
            ? round(max(0, min(100, (1 - $capRisk / $capTotal) * 100)), 2)
            : 100.0;

        // Vital 3 — basket size, normalized against the owner-tunable target.
        $basketRaw = $this->basketSize($wh);
        $basket = $basketTarget > 0 ? round(min(100, $basketRaw / $basketTarget * 100), 2) : 0.0;

        // Vital 4 — count accuracy (null if the branch has no variance data yet).
        $accuracy = $this->countAccuracy($wh);

        $score = $this->blend([
            'hero' => $hero,
            'capital' => $capital,
            'basket' => $basket,
            'accuracy' => $accuracy,
        ]);

        return [
            'score' => $score,
            'hero' => $hero,
            'capital' => $capital,
            'basket' => $basket,
            'accuracy' => $accuracy, // nullable
            'basket_raw' => round($basketRaw, 2),
            'bleeding' => round($bleeding, 2),
            'trapped' => round($trapped, 2),
        ];
    }

    /** Weighted blend over the vitals that have data; missing vitals drop out and weights renormalize. */
    private function blend(array $vitals): float
    {
        $sumW = 0.0;
        $acc = 0.0;
        foreach ($this->weights as $k => $w) {
            $v = $vitals[$k] ?? null;
            if ($v === null) {
                continue;
            }
            $acc += $w * (float) $v;
            $sumW += $w;
        }
        return $sumW > 0 ? round($acc / $sumW, 2) : 0.0;
    }

    /** Average distinct line-items per C0000001 invoice in this warehouse (last 90d). */
    private function basketSize(string $wh): float
    {
        $row = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', 'C0000001')
            ->where('l.warehouse_code', $wh)
            ->whereRaw('i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)')
            ->selectRaw('COUNT(*) line_count, COUNT(DISTINCT l.sap_invoice_id) invoice_count')
            ->first();

        $invoices = (int) ($row->invoice_count ?? 0);
        $lines = (int) ($row->line_count ?? 0);
        return $invoices > 0 ? $lines / $invoices : 0.0;
    }

    /** Average physical-count accuracy (100 − |variance%|) over counted items; null if none. */
    private function countAccuracy(string $wh): ?float
    {
        $row = DB::table('product_abc_classifications')
            ->where('warehouse_code', $wh)
            ->whereNotNull('last_variance_pct')
            ->selectRaw('AVG(GREATEST(0, 100 - ABS(last_variance_pct))) acc, COUNT(*) n')
            ->first();

        if (!$row || (int) $row->n === 0) {
            return null;
        }
        return round((float) $row->acc, 2);
    }

    private function loadWeights(): void
    {
        foreach (array_keys($this->weights) as $k) {
            $v = ZooboxiSetting::get('pulse_w_' . $k, null);
            if ($v !== null && is_numeric($v)) {
                $this->weights[$k] = (float) $v;
            }
        }
    }
}
