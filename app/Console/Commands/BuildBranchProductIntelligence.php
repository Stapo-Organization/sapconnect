<?php

namespace App\Console\Commands;

use App\Services\Intelligence\DemandReconstructionService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Per-branch inventory-intelligence builder (DB-ONLY — never calls SAP).
 *
 * The per-warehouse sibling of intelligence:build-products. For every real
 * warehouse it reconstructs that branch's velocity, days-of-cover, stockout-
 * corrected health and capital-at-risk from C0000001 retail sales, this
 * warehouse's stock and GRPO arrivals — and writes one row per (item, warehouse)
 * into `branch_product_intelligence`. This is the data spine of نبض المعرض.
 *
 * Only items the warehouse actually holds (stock>0) or has sold in the last
 * 365d get a row, so the table reflects the real showroom, not the catalog.
 *
 * NOTE: like build-products, the on-hand reconstruction uses GRPO arrivals +
 * sales outflow; inter-branch transfer movements are not yet folded in (a known
 * approximation — refine later if a branch is mostly transfer-fed).
 */
class BuildBranchProductIntelligence extends Command
{
    protected $signature = 'intelligence:build-branch-products
        {--window=90 : Reconstruction window in days}
        {--warehouse= : Limit to a single warehouse code}';

    protected $description = 'Build branch_product_intelligence (per-warehouse velocity, cover, health, capital-at-risk) — DB only.';

    /**
     * Coverage a branch should hold before stock counts as trapped excess.
     * 90 days (owner decision) — tighter than the 180-day store/clearance target
     * so the branch "حرّر فلوسك" lever surfaces idle cash earlier.
     */
    private const COVER_TARGET_DAYS = 90;

    public function handle(DemandReconstructionService $recon): int
    {
        ini_set('memory_limit', '1024M'); // scheduler runs without -d memory_limit
        DB::connection()->disableQueryLog();
        $window = max(30, (int) $this->option('window'));
        $today = Carbon::today();
        $now = now();

        // Real branch codes that hold stock (never the '' item-level rollup).
        $warehouses = DB::table('warehouse_item_stocks')
            ->select('warehouse_code')->distinct()
            ->when($this->option('warehouse'), fn ($q) => $q->where('warehouse_code', $this->option('warehouse')))
            ->whereNotNull('warehouse_code')->where('warehouse_code', '!=', '')
            ->pluck('warehouse_code');

        $this->info("Building branch_product_intelligence for {$warehouses->count()} warehouse(s), window={$window}d...");

        // Item-level maps shared across all warehouses (one query each).
        $cost = DB::table('product_costs')->pluck('cost_proxy_sar', 'item_code');
        $prices = DB::table('products')->pluck('prices', 'item_code');
        $created = DB::table('products')->pluck('created_at', 'item_code');

        $total = 0;
        foreach ($warehouses as $wh) {
            $rows = $this->buildWarehouse($wh, $window, $today, $now, $recon, $cost, $prices, $created);
            foreach (array_chunk($rows, 500) as $chunk) {
                $this->flush($chunk);
                $total += count($chunk);
            }
            // Drop rows for items this warehouse no longer holds/sells (stale = older computed_at).
            DB::table('branch_product_intelligence')
                ->where('warehouse_code', $wh)
                ->where('computed_at', '<', $now)
                ->delete();
            $this->line("  {$wh}: " . count($rows) . ' items');
        }

        $this->info("Built branch_product_intelligence: {$total} rows.");
        return self::SUCCESS;
    }

    /** @return array<int,array<string,mixed>> upsert rows for one warehouse */
    private function buildWarehouse(string $wh, int $window, Carbon $today, $now, DemandReconstructionService $recon, $cost, $prices, $created): array
    {
        // Per-warehouse stock on hand + committed (reserved by open sales orders).
        $stockRows = DB::table('warehouse_item_stocks')
            ->where('warehouse_code', $wh)
            ->get(['item_code', 'in_stock', 'committed']);
        $stock = $stockRows->pluck('in_stock', 'item_code');
        $committedMap = $stockRows->pluck('committed', 'item_code');

        // Per-warehouse C0000001 retail sales windows.
        $sales = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', 'C0000001')
            ->where('l.warehouse_code', $wh)
            ->selectRaw('l.item_code,
                SUM(CASE WHEN i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)  THEN l.quantity ELSE 0 END) s30,
                SUM(CASE WHEN i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)  THEN l.quantity ELSE 0 END) s90,
                SUM(CASE WHEN i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY) THEN l.quantity ELSE 0 END) s365,
                MAX(i.doc_date) last_sale')
            ->groupBy('l.item_code')
            ->get()->keyBy('item_code');

        $abc = DB::table('product_abc_classifications')
            ->where('warehouse_code', $wh)
            ->pluck('abc_class', 'item_code');

        // Movement deltas for the reconstruction window (this warehouse).
        $arrivals = $recon->dayMap(
            DB::table('sap_goods_receipt_lines')
                ->where('warehouse_code', $wh)
                ->whereRaw('doc_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$window])
                ->selectRaw('item_code, doc_date, SUM(inventory_quantity) q')
                ->groupBy('item_code', 'doc_date')->get(),
            $today
        );
        $outflow = $recon->dayMap(
            DB::table('sap_invoice_lines as l')
                ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
                ->where('l.warehouse_code', $wh)
                ->whereRaw('i.doc_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$window])
                ->selectRaw('l.item_code, i.doc_date, SUM(l.quantity) q')
                ->groupBy('l.item_code', 'i.doc_date')->get(),
            $today
        );

        // Items this warehouse actually touches: stocked OR sold (365d).
        $codes = $stock->keys()->merge($sales->keys())->unique();

        $rows = [];
        foreach ($codes as $code) {
            $s = $sales[$code] ?? null;
            $s30 = (float) ($s->s30 ?? 0);
            $s90 = (float) ($s->s90 ?? 0);
            $s365 = (float) ($s->s365 ?? 0);
            $lastSale = $s->last_sale ?? null;
            $st = (float) ($stock[$code] ?? 0);
            // Available = physical − committed: committed units are reserved for
            // open sales orders, so they are NOT idle/trapped capital.
            $committed = (float) ($committedMap[$code] ?? 0);
            $available = max(0, $st - $committed);

            $ads30 = $s30 / 30;
            $ads90 = $s90 / 90;
            $velocity = 0.6 * $ads30 + 0.4 * $ads90;

            [$inStockDays, $inStockRate] = $recon->reconstruct(
                $st,
                $arrivals[$code] ?? [],
                $outflow[$code] ?? [],
                $window
            );
            $vTrue = $s90 / max($inStockDays, 1);
            $lostMonthly = $vTrue * max(0, $window - $inStockDays) / ($window / 30);

            $cover = $velocity > 1e-6 ? $st / $velocity : null;

            $retail = $recon->retailPrice($prices[$code] ?? null);
            $unitCost = isset($cost[$code]) ? (float) $cost[$code] : null;

            $health = $recon->classifyHealth($st, $s90, $s365, $cover, $inStockRate, $vTrue, self::COVER_TARGET_DAYS);
            $demand = $recon->classifyDemand($s90, $s365, $lastSale, $created[$code] ?? null);

            // Stockout-robust demand rate: how fast it sells WHEN AVAILABLE, so a
            // recent out-of-stock / no-sale stretch can't deflate it into a fake
            // overstock. (Calendar velocity divides by all days, stocked or not.)
            $demandRate = max($ads90, $s365 / 365.0, $vTrue);

            // Trapped capital is excess of AVAILABLE stock vs that demand — never the
            // committed portion (already sold/reserved and leaving soon).
            $excess = 0.0;
            if ($health === 'overstock') {
                $excess = max(0, $available - $demandRate * self::COVER_TARGET_DAYS);
            } elseif ($health === 'dead') {
                $excess = $available;
            }
            $valuePerUnit = $unitCost ?? ($retail !== null ? $retail * 0.6 : 0);
            $capitalAtRisk = round($excess * $valuePerUnit, 2);

            $rows[] = [
                'item_code' => $code,
                'warehouse_code' => $wh,
                'ads_30' => round($ads30, 4),
                'ads_90' => round($ads90, 4),
                'velocity_blended' => round($velocity, 4),
                'demand_rate' => round($demandRate, 4),
                'demand_class' => $demand,
                'last_sale_date' => $lastSale,
                'is_never_sold' => $lastSale === null,
                'current_stock' => round($st, 4),
                'days_of_cover' => $cover === null ? null : round($cover, 2),
                'in_stock_rate' => round($inStockRate, 4),
                'v_true' => round($vTrue, 4),
                'lost_sales_monthly' => round($lostMonthly, 4),
                'health_status' => $health,
                'excess_units' => round($excess, 4),
                'unit_cost_sar' => $unitCost,
                'unit_retail_sar' => $retail,
                'capital_at_risk_sar' => $capitalAtRisk,
                'abc_class' => $abc[$code] ?? null,
                'is_hero' => $velocity >= DemandReconstructionService::HERO_PER_DAY,
                'computed_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }
        return $rows;
    }

    private function flush(array $rows): void
    {
        DB::table('branch_product_intelligence')->upsert(
            $rows,
            ['item_code', 'warehouse_code'],
            [
                'ads_30', 'ads_90', 'velocity_blended', 'demand_rate', 'demand_class', 'last_sale_date',
                'is_never_sold', 'current_stock', 'days_of_cover', 'in_stock_rate', 'v_true',
                'lost_sales_monthly', 'health_status', 'excess_units', 'unit_cost_sar',
                'unit_retail_sar', 'capital_at_risk_sar', 'abc_class', 'is_hero',
                'computed_at', 'updated_at',
            ]
        );
    }
}
