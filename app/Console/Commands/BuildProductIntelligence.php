<?php

namespace App\Console\Commands;

use App\Services\Intelligence\DemandReconstructionService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Zooboxi inventory-intelligence builder (DB-ONLY — never calls SAP).
 *
 * Reads C0000001 retail sales (96% of invoices), current warehouse stock, the imported
 * GRPO arrivals, and product_costs — all from the sapconnect DB — and writes one
 * item-level row per product into `product_intelligence`.
 *
 * Velocity & stock are in the same inventory unit (pieces, verified), so NO
 * sales_items_per_unit conversion is applied. Stockout correction reconstructs the
 * last 90 days of on-hand (arrivals − all-sales; transfers cancel at item level) to
 * tell a genuinely DEAD product from a STARVED one (good seller that ran out).
 */
class BuildProductIntelligence extends Command
{
    protected $signature = 'intelligence:build-products {--window=90 : Reconstruction window in days}';
    protected $description = 'Build product_intelligence (stockout-corrected velocity, cover, health, capital-at-risk) — DB only.';

    private const HERO_PER_DAY = 3.33;   // >= ~100/month
    private const COVER_TARGET_DAYS = 180;
    private const SCORE_VERSION = 'v1';

    /** Composite ranking weights (owner-tunable via ZooboxiSetting → Filament). */
    private array $weights = [
        'avail' => 0.30, 'pop' => 0.26, 'margin' => 0.14, 'clearance' => 0.24, 'freshness' => 0.06,
    ];

    private function loadWeights(): void
    {
        foreach (array_keys($this->weights) as $k) {
            $v = \App\Models\ZooboxiSetting::get('rank_w_' . $k, null);
            if ($v !== null && is_numeric($v)) {
                $this->weights[$k] = (float) $v;
            }
        }
    }

    public function handle(DemandReconstructionService $recon): int
    {
        ini_set('memory_limit', '1024M'); // scheduler runs without -d memory_limit
        DB::connection()->disableQueryLog();
        $this->loadWeights();
        $window = max(30, (int) $this->option('window'));
        $today = Carbon::today();
        $this->info("Building product_intelligence (window={$window}d)...");

        // ---- 1) Set-based maps (one query each), keyed by item_code -------------
        $stock = DB::table('warehouse_item_stocks')
            ->selectRaw('item_code, SUM(in_stock) s')->groupBy('item_code')
            ->pluck('s', 'item_code');

        $sales = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', 'C0000001')
            ->selectRaw('l.item_code,
                SUM(CASE WHEN i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)  THEN l.quantity ELSE 0 END) s30,
                SUM(CASE WHEN i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)  THEN l.quantity ELSE 0 END) s90,
                SUM(CASE WHEN i.doc_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY) THEN l.quantity ELSE 0 END) s365,
                MAX(i.doc_date) last_sale')
            ->groupBy('l.item_code')
            ->get()->keyBy('item_code');

        $cost = DB::table('product_costs')->pluck('cost_proxy_sar', 'item_code');
        $abc = DB::table('product_abc_classifications')
            ->selectRaw('item_code, MIN(abc_class) c')->groupBy('item_code')
            ->pluck('c', 'item_code');

        // ---- 2) Movement deltas for the reconstruction window ------------------
        // arrivals: GRPO inventory_quantity (pieces). all-sales: every card_code.
        $arrivals = $recon->dayMap(
            DB::table('sap_goods_receipt_lines')
                ->whereRaw('doc_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$window])
                ->selectRaw('item_code, doc_date, SUM(inventory_quantity) q')
                ->groupBy('item_code', 'doc_date')->get(),
            $today
        );
        $outflow = $recon->dayMap(
            DB::table('sap_invoice_lines as l')
                ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
                ->whereRaw('i.doc_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)', [$window])
                ->selectRaw('l.item_code, i.doc_date, SUM(l.quantity) q')
                ->groupBy('l.item_code', 'i.doc_date')->get(),
            $today
        );

        // ---- 3) First pass: per-item metrics (collect velocities for percentile)
        $items = [];
        $velocities = [];
        $products = DB::table('products')
            ->where('zooboxi_active', 1)
            ->select('item_code', 'prices', 'created_at')
            ->get();

        foreach ($products as $p) {
            $code = $p->item_code;
            $s = $sales[$code] ?? null;
            $s30 = (float) ($s->s30 ?? 0);
            $s90 = (float) ($s->s90 ?? 0);
            $s365 = (float) ($s->s365 ?? 0);
            $lastSale = $s->last_sale ?? null;
            $st = (float) ($stock[$code] ?? 0);

            $ads30 = $s30 / 30;
            $ads90 = $s90 / 90;
            $velocity = 0.6 * $ads30 + 0.4 * $ads90;

            // Stockout reconstruction over the window.
            [$inStockDays, $inStockRate] = $recon->reconstruct(
                $st,
                $arrivals[$code] ?? [],
                $outflow[$code] ?? [],
                $window
            );
            $vTrue = $s90 / max($inStockDays, 1);
            $lostMonthly = $vTrue * max(0, $window - $inStockDays) / ($window / 30);

            $cover = $velocity > 1e-6 ? $st / $velocity : null;

            $retail = $recon->retailPrice($p->prices);
            $unitCost = isset($cost[$code]) ? (float) $cost[$code] : null;

            $health = $recon->classifyHealth($st, $s90, $s365, $cover, $inStockRate, $vTrue);
            $demand = $recon->classifyDemand($s90, $s365, $lastSale, $p->created_at);

            $excess = 0.0;
            if ($health === 'overstock') {
                $excess = max(0, $st - $velocity * self::COVER_TARGET_DAYS);
            } elseif ($health === 'dead') {
                $excess = $st;
            }
            $valuePerUnit = $unitCost ?? ($retail !== null ? $retail * 0.6 : 0);
            $capitalAtRisk = round($excess * $valuePerUnit, 2);

            $velocities[] = $velocity;
            $items[$code] = [
                'ads_30' => round($ads30, 4),
                'ads_90' => round($ads90, 4),
                'velocity_blended' => round($velocity, 4),
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
                'is_hero' => $velocity >= self::HERO_PER_DAY,
                '_retail' => $retail,
                '_cost' => $unitCost,
                '_cover' => $cover,
                '_created' => $p->created_at,
            ];
        }
        unset($products, $arrivals, $outflow, $sales, $stock);

        // ---- 4) Percentile of velocity for the popularity term -----------------
        sort($velocities);
        $n = count($velocities);

        // ---- 5) Second pass: composite score + bulk upsert --------------------
        $now = now();
        $rows = [];
        $count = 0;
        foreach ($items as $code => $m) {
            $score = $this->compositeScore($m, $velocities, $n, $today);
            $rows[] = [
                'item_code' => $code,
                'warehouse_code' => '',
                'ads_30' => $m['ads_30'],
                'ads_90' => $m['ads_90'],
                'velocity_blended' => $m['velocity_blended'],
                'demand_class' => $m['demand_class'],
                'last_sale_date' => $m['last_sale_date'],
                'is_never_sold' => $m['is_never_sold'],
                'current_stock' => $m['current_stock'],
                'days_of_cover' => $m['days_of_cover'],
                'in_stock_rate' => $m['in_stock_rate'],
                'v_true' => $m['v_true'],
                'lost_sales_monthly' => $m['lost_sales_monthly'],
                'health_status' => $m['health_status'],
                'excess_units' => $m['excess_units'],
                'unit_cost_sar' => $m['unit_cost_sar'],
                'unit_retail_sar' => $m['unit_retail_sar'],
                'capital_at_risk_sar' => $m['capital_at_risk_sar'],
                'abc_class' => $m['abc_class'],
                'is_hero' => $m['is_hero'],
                'composite_rank_score' => round($score, 4),
                'score_version' => self::SCORE_VERSION,
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

        $this->info("Built product_intelligence for {$count} items.");
        return self::SUCCESS;
    }

    private function compositeScore(array $m, array $sortedVel, int $n, Carbon $today): float
    {
        $stock = $m['current_stock'];
        $vel = $m['velocity_blended'];

        $availGate = $stock > 0 ? 1.0 : 0.05;
        $avail = $vel > 1e-6 ? min(1.0, $stock / (7 * $vel)) : ($stock > 0 ? 1.0 : 0.0);

        // Popularity = percentile rank of velocity (upper bound / n).
        $pop = $n > 0 ? $this->upperBound($sortedVel, $vel) / $n : 0.0;

        $retail = $m['_retail'];
        $cost = $m['_cost'];
        $margin = ($retail && $cost && $retail > 0)
            ? min(max(($retail - $cost) / $retail, 0), 0.6) / 0.6
            : 0.3;

        $cover = $m['_cover'];
        $clearance = 0.0;
        if ($cover !== null && in_array($m['health_status'], ['overstock', 'dead'], true)) {
            $clearance = 1 / (1 + exp(-(($cover - self::COVER_TARGET_DAYS) / 60)));
        }

        $freshness = 0.0;
        if ($m['_created']) {
            $age = abs($today->diffInDays(Carbon::parse($m['_created'])));
            $freshness = exp(-$age / 45);
        }

        $w = $this->weights;
        $score = 100 * $availGate * ($w['avail'] * $avail + $w['pop'] * $pop + $w['margin'] * $margin + $w['clearance'] * $clearance + $w['freshness'] * $freshness);

        // A-class proven sellers never sink while B2C history is empty.
        if ($m['abc_class'] === 'A') {
            $score = max($score, 5 * $availGate);
        }
        return $score;
    }

    /** Count of values <= $v in a sorted ascending array (upper bound index). */
    private function upperBound(array $sorted, float $v): int
    {
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
        return $lo;
    }

    private function flush(array $rows): void
    {
        DB::table('product_intelligence')->upsert(
            $rows,
            ['item_code', 'warehouse_code'],
            [
                'ads_30', 'ads_90', 'velocity_blended', 'demand_class', 'last_sale_date',
                'is_never_sold', 'current_stock', 'days_of_cover', 'in_stock_rate', 'v_true',
                'lost_sales_monthly', 'health_status', 'excess_units', 'unit_cost_sar',
                'unit_retail_sar', 'capital_at_risk_sar', 'abc_class', 'is_hero',
                'composite_rank_score', 'score_version', 'computed_at', 'updated_at',
            ]
        );
    }
}
