<?php

namespace App\Services\Branch;

use App\Models\InventoryCounting;
use App\Models\QualityTaskInstance;
use App\Models\StockTransfer;
use App\Models\Warehouse;
use App\Models\ZooboxiOrder;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * BranchInsightsService — read-only aggregation behind the owner's Retail
 * Dashboard. It stitches together the data sources that already exist:
 *
 *   • Sales / revenue   →  sap_invoices + sap_credit_memos (card_code C0000001),
 *                          attributed to a store by sales_employee_code — the same
 *                          basis as the Filament StoreSalesWidget / store dashboards.
 *   • Health / score    →  branch_pulse_scores (4 vitals + composite + rank),
 *                          built daily by `intelligence:build-branch-pulse`.
 *   • Money levers       →  branch_product_intelligence (bleeding / trapped).
 *   • Operations         →  quality_task_instances, inventory_countings,
 *                          sap_stock_transfers, zooboxi_orders.
 *
 * Everything here is SAP-read-only; nothing is written back.
 */
class BranchInsightsService
{
    private const RETAIL_CARD = 'C0000001';

    /**
     * Arabic display names for the showrooms (the warehouse master stores English
     * names, and three codes have none). District + city for Riyadh's multiple
     * stores; bare city elsewhere. Falls back to the master name then the code.
     */
    public const AR_NAMES = [
        'RUH002' => 'النصر · الرياض',
        'RUH004' => 'الربيع · الرياض',
        'RUH005' => 'قرطبة · الرياض',
        'RUH006' => 'السليمانية · الرياض',
        'RUH007' => 'الروابي · الرياض',
        'RUH008' => 'السويدي · الرياض',
        'DMM001' => 'الدمام',
        'JED002' => 'جدة',
        'MED001' => 'المدينة المنورة',
        'ABH001' => 'أبها',
        'UZH001' => 'عنيزة',
        'KHO001' => 'الخبر',
        'BRD001' => 'بريدة',
        'HBT001' => 'حوطة بني تميم',
    ];

    /** Arabic showroom name with graceful fallback (master English name → code). */
    public static function arName(string $code, ?string $fallback = null): string
    {
        return self::AR_NAMES[$code] ?? ($fallback ?: $code);
    }

    // ─── Branch directory ────────────────────────────────────────

    /**
     * The list of "exhibitions" the dashboard ranks: warehouses that actually
     * ring up retail (C0000001) sales. The bridge from a sale to a branch is the
     * line-level warehouse_code on the invoice — warehouses.sales_employee_code
     * is unpopulated, and the invoice header's sales_employee_code is a SAP
     * sales-person code, not a warehouse. A 90-day window keeps the store set
     * stable regardless of the dashboard's period filter.
     *
     * @return \Illuminate\Support\Collection<string, object>
     */
    public function exhibitions(): \Illuminate\Support\Collection
    {
        $codes = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', self::RETAIL_CARD)
            ->where('i.doc_date', '>=', now()->subDays(90)->toDateString())
            ->whereNotNull('l.warehouse_code')
            ->distinct()
            ->pluck('l.warehouse_code')
            ->all();

        if (empty($codes)) {
            return collect();
        }

        // Resolve names from the warehouse master, but DON'T drop a selling store
        // that's missing from it (the master table is incomplete on prod) — fall
        // back to the code so every branch with retail sales still appears.
        $names = Warehouse::whereIn('warehouse_code', $codes)->pluck('warehouse_name', 'warehouse_code');

        return collect($codes)
            ->sort()
            ->mapWithKeys(fn ($code) => [
                $code => (object) [
                    'warehouse_code' => $code,
                    'warehouse_name' => self::arName($code, $names[$code] ?? null),
                ],
            ]);
    }

    public function warehouseName(string $code): string
    {
        return (string) (Warehouse::where('warehouse_code', $code)->value('warehouse_name') ?: $code);
    }

    // ─── Period parsing ──────────────────────────────────────────

    /**
     * Resolve a period filter into a [start, end] Carbon pair.
     * Accepts: today | week | month (default) | custom (with from/to).
     *
     * @return array{0: Carbon, 1: Carbon, 2: string}
     */
    public function resolvePeriod(?string $period, ?string $from, ?string $to): array
    {
        $period = $period ?: 'month';
        $today = Carbon::today();

        switch ($period) {
            case 'today':
                return [$today->copy()->startOfDay(), $today->copy()->endOfDay(), 'today'];
            case 'week':
                return [$today->copy()->startOfWeek(), $today->copy()->endOfDay(), 'week'];
            case 'custom':
                $start = $from ? Carbon::parse($from)->startOfDay() : $today->copy()->startOfMonth();
                $end = $to ? Carbon::parse($to)->endOfDay() : $today->copy()->endOfDay();
                return [$start, $end, 'custom'];
            case 'month':
            default:
                return [$today->copy()->startOfMonth(), $today->copy()->endOfDay(), 'month'];
        }
    }

    // ─── Sales / revenue ─────────────────────────────────────────

    /**
     * Net retail sales per warehouse over [start,end].
     * Returns warehouse_code => ['gross','returns','net','invoices'].
     *
     * doc_total lives on the document header; lines carry the warehouse. A retail
     * POS sale is a single store, so we attribute each document to one warehouse
     * (MIN(line.warehouse_code)) and de-duplicate the header total per document
     * (MAX) before summing — otherwise a 5-line invoice would be counted 5×.
     */
    public function revenueByWarehouse(Carbon $start, Carbon $end): array
    {
        $invoices = $this->dedupTotalsByWarehouse('sap_invoices', 'sap_invoice_lines', 'sap_invoice_id', $start, $end);
        $returns = $this->dedupTotalsByWarehouse('sap_credit_memos', 'sap_credit_memo_lines', 'sap_credit_memo_id', $start, $end);

        $out = [];
        foreach ($invoices as $wc => $row) {
            $gross = (float) $row->total;
            $ret = isset($returns[$wc]) ? (float) $returns[$wc]->total : 0.0;
            $out[$wc] = [
                'gross' => round($gross, 2),
                'returns' => round($ret, 2),
                'net' => round($gross - $ret, 2),
                'invoices' => (int) $row->cnt,
            ];
        }
        return $out;
    }

    /**
     * Per-warehouse SAR totals, de-duplicated to one header doc_total per
     * document. Table/column names are internal constants (not user input).
     *
     * @return \Illuminate\Support\Collection<string, object>
     */
    private function dedupTotalsByWarehouse(string $headerTable, string $lineTable, string $fk, Carbon $start, Carbon $end): \Illuminate\Support\Collection
    {
        $rows = DB::select(
            "SELECT t.warehouse_code wc, SUM(t.doc_total) total, COUNT(*) cnt FROM (
                SELECT h.id, MAX(h.doc_total) doc_total, MIN(l.warehouse_code) warehouse_code
                FROM {$headerTable} h JOIN {$lineTable} l ON l.{$fk} = h.id
                WHERE h.card_code = ? AND h.doc_date BETWEEN ? AND ?
                GROUP BY h.id
             ) t WHERE t.warehouse_code IS NOT NULL GROUP BY t.warehouse_code",
            [self::RETAIL_CARD, $start->toDateTimeString(), $end->toDateTimeString()]
        );
        return collect($rows)->keyBy('wc');
    }

    /** Empty revenue shape (store with no sales in the period). */
    public function emptyRevenue(): array
    {
        return ['gross' => 0.0, 'returns' => 0.0, 'net' => 0.0, 'invoices' => 0];
    }

    /**
     * Combined sales + actual-profit time series (ex-VAT, from synced line
     * economics), bucketed by hour (today) or day (week/month). Optionally
     * scoped to one warehouse. Continuous buckets — gaps filled with zero.
     *
     * @return array{granularity:string, points: array<int, array{label:string, sales:float, profit:float}>}
     */
    public function salesProfitTrend(Carbon $start, Carbon $end, string $granularity, ?string $warehouseCode = null): array
    {
        $hourly = $granularity === 'hour';

        $q = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', self::RETAIL_CARD)
            ->whereBetween('i.doc_date', [$start, $end])
            ->whereNotNull('l.gross_profit');
        if ($warehouseCode !== null) {
            $q->where('l.warehouse_code', $warehouseCode);
        }

        if ($hourly) {
            $rows = $q->whereNotNull('i.doc_time') // un-timed invoices would all pile into hour 0
                ->groupBy(DB::raw('HOUR(i.doc_time)'))
                ->select(DB::raw('HOUR(i.doc_time) k'), DB::raw('SUM(l.line_revenue) sales'), DB::raw('SUM(l.gross_profit) profit'))
                ->get()->keyBy('k');
            // Fill from the first to the last hour that has sales (compact business window).
            $hours = $rows->keys()->map(fn ($h) => (int) $h)->all();
            if (empty($hours)) {
                return ['granularity' => 'hour', 'points' => []];
            }
            $lo = max(0, min($hours));
            $hi = min(23, max($hours));
            $points = [];
            for ($h = $lo; $h <= $hi; $h++) {
                $r = $rows[$h] ?? null;
                $points[] = [
                    'label' => sprintf('%02d:00', $h),
                    'sales' => round((float) ($r->sales ?? 0), 2),
                    'profit' => round((float) ($r->profit ?? 0), 2),
                ];
            }
            return ['granularity' => 'hour', 'points' => $points];
        }

        $rows = $q->groupBy(DB::raw('DATE(i.doc_date)'))
            ->select(DB::raw('DATE(i.doc_date) k'), DB::raw('SUM(l.line_revenue) sales'), DB::raw('SUM(l.gross_profit) profit'))
            ->get()->keyBy('k');

        $points = [];
        $cursor = $start->copy()->startOfDay();
        $last = $end->copy()->startOfDay();
        $guard = 0;
        while ($cursor->lte($last) && $guard < 120) {
            $key = $cursor->toDateString();
            $r = $rows[$key] ?? null;
            $points[] = [
                'label' => $key,
                'sales' => round((float) ($r->sales ?? 0), 2),
                'profit' => round((float) ($r->profit ?? 0), 2),
            ];
            $cursor->addDay();
            $guard++;
        }
        return ['granularity' => 'day', 'points' => $points];
    }

    /** Saudi VAT rate — net invoice totals (doc_total) include 15% VAT. */
    private const VAT_DIVISOR = 1.15;

    /**
     * Estimated gross-profit margin per warehouse, as a fraction (0..1).
     *
     * Cost data (product_costs → branch_product_intelligence.unit_cost_sar) has
     * unit-inconsistent outliers (some items priced per carton vs sold per piece),
     * and there is no clean margin field. So we take a ROBUST blended margin:
     * compute each sold item's margin (1 − cost/retail), keep only the ones in a
     * sane band [2%, 70%], weight by item revenue, and blend. That outlier-resistant
     * margin is then applied to the store's whole ex-VAT revenue by the caller.
     * It is an ESTIMATE — surface it labelled as such.
     *
     * @return array<string, float> warehouse_code => margin fraction (0..1)
     */
    public function blendedMarginByWarehouse(Carbon $start, Carbon $end): array
    {
        $rows = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->join('branch_product_intelligence as b', function ($j) {
                $j->on('b.item_code', '=', 'l.item_code')->on('b.warehouse_code', '=', 'l.warehouse_code');
            })
            ->where('i.card_code', self::RETAIL_CARD)
            ->whereBetween('i.doc_date', [$start, $end])
            ->where('b.unit_retail_sar', '>', 0)
            ->where('b.unit_cost_sar', '>', 0)
            ->groupBy('l.warehouse_code', 'l.item_code', 'b.unit_cost_sar', 'b.unit_retail_sar')
            ->select(
                'l.warehouse_code',
                DB::raw('SUM(l.quantity) qty'),
                DB::raw('b.unit_cost_sar uc'),
                DB::raw('b.unit_retail_sar ur')
            )
            ->get();

        $acc = [];
        foreach ($rows as $r) {
            $margin = 1 - ((float) $r->uc / (float) $r->ur);
            if ($margin < 0.02 || $margin > 0.70) {
                continue; // outlier / dirty cost — excluded from the blend
            }
            $rev = (float) $r->qty * (float) $r->ur;
            $acc[$r->warehouse_code]['rev'] = ($acc[$r->warehouse_code]['rev'] ?? 0) + $rev;
            $acc[$r->warehouse_code]['profit'] = ($acc[$r->warehouse_code]['profit'] ?? 0) + $rev * $margin;
        }

        $out = [];
        foreach ($acc as $wc => $a) {
            if (($a['rev'] ?? 0) > 0) {
                $out[$wc] = $a['profit'] / $a['rev'];
            }
        }
        return $out;
    }

    /**
     * ACTUAL gross profit per warehouse, straight from SAP's per-line economics
     * (GrossProfit / LineTotal, synced into sap_invoice_lines), net of returns.
     * Only warehouses with synced profit rows appear; the rest fall back to the
     * blended estimate. Returns code => { profit, margin_pct, estimated:false }.
     *
     * @return array<string, array>
     */
    public function actualProfitByWarehouse(Carbon $start, Carbon $end): array
    {
        $agg = fn (string $lineTable, string $headerTable, string $fk) => DB::table("{$lineTable} as l")
            ->join("{$headerTable} as h", 'h.id', '=', "l.{$fk}")
            ->where('h.card_code', self::RETAIL_CARD)
            ->whereBetween('h.doc_date', [$start, $end])
            ->whereNotNull('l.gross_profit')
            ->whereNotNull('l.warehouse_code')
            ->groupBy('l.warehouse_code')
            ->select('l.warehouse_code', DB::raw('SUM(l.gross_profit) gp'), DB::raw('SUM(l.line_revenue) rev'))
            ->get()->keyBy('warehouse_code');

        $inv = $agg('sap_invoice_lines', 'sap_invoices', 'sap_invoice_id');
        $ret = $agg('sap_credit_memo_lines', 'sap_credit_memos', 'sap_credit_memo_id');

        $out = [];
        foreach ($inv as $wc => $row) {
            $gp = (float) $row->gp - (float) ($ret[$wc]->gp ?? 0);
            $rev = (float) $row->rev - (float) ($ret[$wc]->rev ?? 0);
            $out[$wc] = [
                'profit' => round($gp, 2),
                'margin_pct' => $rev > 0 ? round($gp / $rev * 100, 1) : null,
                'estimated' => false,
            ];
        }
        return $out;
    }

    /**
     * Estimated profit block for a store from its net (incl-VAT) revenue and a
     * blended margin: { profit (ex-VAT SAR), margin_pct, estimated:true }.
     */
    public function profitBlock(float $netInclVat, ?float $marginFraction): array
    {
        if ($marginFraction === null) {
            return ['profit' => 0.0, 'margin_pct' => null, 'estimated' => true];
        }
        $exVat = $netInclVat / self::VAT_DIVISOR;
        return [
            'profit' => round($exVat * $marginFraction, 2),
            'margin_pct' => round($marginFraction * 100, 1),
            'estimated' => true,
        ];
    }

    /**
     * Daily sales trend for one warehouse (invoice totals, de-duplicated per
     * document). Returns are not netted per-day — they're a small share and the
     * trend is indicative.
     */
    public function revenueTrend(string $warehouseCode, Carbon $start, Carbon $end): array
    {
        $byDay = collect(DB::select(
            "SELECT DATE(t.doc_date) d, SUM(t.doc_total) total FROM (
                SELECT i.id, MAX(i.doc_total) doc_total, MAX(i.doc_date) doc_date, MIN(l.warehouse_code) warehouse_code
                FROM sap_invoices i JOIN sap_invoice_lines l ON l.sap_invoice_id = i.id
                WHERE i.card_code = ? AND i.doc_date BETWEEN ? AND ?
                GROUP BY i.id
             ) t WHERE t.warehouse_code = ? GROUP BY DATE(t.doc_date)",
            [self::RETAIL_CARD, $start->toDateTimeString(), $end->toDateTimeString(), $warehouseCode]
        ))->pluck('total', 'd');

        $out = [];
        $cursor = $start->copy()->startOfDay();
        $last = $end->copy()->startOfDay();
        // Cap to ~120 points so a wide custom range can't blow up the payload.
        $guard = 0;
        while ($cursor->lte($last) && $guard < 120) {
            $key = $cursor->toDateString();
            $out[] = ['date' => $key, 'net' => round((float) ($byDay[$key] ?? 0), 2)];
            $cursor->addDay();
            $guard++;
        }
        return $out;
    }

    /** Top selling products for a store, ranked by units sold (lines carry warehouse_code). */
    public function topProducts(string $warehouseCode, Carbon $start, Carbon $end, int $limit = 10): array
    {
        $rows = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', self::RETAIL_CARD)
            ->where('l.warehouse_code', $warehouseCode)
            ->whereBetween('i.doc_date', [$start, $end])
            ->select('l.item_code', DB::raw('SUM(l.quantity) as units'))
            ->groupBy('l.item_code')
            ->orderByDesc('units')
            ->limit($limit)
            ->get();

        $meta = $this->productMeta($rows->pluck('item_code')->all());

        return $rows->map(fn ($r) => [
            'item_code' => $r->item_code,
            'name' => $meta[$r->item_code]['name'] ?? $r->item_code,
            'image_url' => $meta[$r->item_code]['image_url'] ?? $this->imageUrl($r->item_code),
            'units' => (float) $r->units,
        ])->all();
    }

    // ─── Operations counters ─────────────────────────────────────

    public function opsCounts(string $warehouseCode): array
    {
        $qualityPending = QualityTaskInstance::where('warehouse_code', $warehouseCode)
            ->where('status', QualityTaskInstance::STATUS_PENDING)->count();

        $countingActive = InventoryCounting::where('warehouse_code', $warehouseCode)
            ->where('status', InventoryCounting::STATUS_IN_PROGRESS)->count();

        $transfersNew = StockTransfer::forWarehouse([$warehouseCode])
            ->where('internal_status', StockTransfer::STATUS_NEW)->count();

        $zooboxiPending = ZooboxiOrder::forWarehouse($warehouseCode)
            ->where('delivery_status', ZooboxiOrder::STATUS_PENDING)->count();

        $zooboxiUrgent = ZooboxiOrder::forWarehouse($warehouseCode)
            ->where('delivery_status', ZooboxiOrder::STATUS_PENDING)
            ->whereIn('delivery_type', ['express', 'same_day'])->count();

        return [
            'quality_pending' => $qualityPending,
            'counting_active' => $countingActive,
            'transfers_new' => $transfersNew,
            'zooboxi_pending' => $zooboxiPending,
            'zooboxi_urgent' => $zooboxiUrgent,
        ];
    }

    // ─── Pulse score / vitals ────────────────────────────────────

    public function pulseRow(string $warehouseCode): ?object
    {
        return DB::table('branch_pulse_scores')->where('warehouse_code', $warehouseCode)->first();
    }

    public function scoreBlock(?object $pulse): ?array
    {
        if (!$pulse) {
            return null;
        }
        $prev = $pulse->score_prev !== null ? (float) $pulse->score_prev : null;
        return [
            'value' => round((float) $pulse->score, 1),
            'prev' => $prev !== null ? round($prev, 1) : null,
            'trend' => $prev !== null ? round((float) $pulse->score - $prev, 1) : null,
            'rank' => $pulse->rank !== null ? (int) $pulse->rank : null,
            'total_branches' => $pulse->total_branches !== null ? (int) $pulse->total_branches : null,
            'computed_at' => $pulse->computed_at,
        ];
    }

    public function vitalsBlock(?object $pulse): array
    {
        if (!$pulse) {
            return [];
        }
        return [
            ['key' => 'hero_availability', 'value' => round((float) $pulse->vital_hero_availability, 1)],
            ['key' => 'capital_efficiency', 'value' => round((float) $pulse->vital_capital_efficiency, 1)],
            ['key' => 'basket_size', 'value' => round((float) $pulse->vital_basket_size, 1), 'raw' => round((float) $pulse->basket_items_per_invoice, 2)],
            ['key' => 'count_accuracy', 'value' => $pulse->vital_count_accuracy !== null ? round((float) $pulse->vital_count_accuracy, 1) : null],
        ];
    }

    // ─── Money levers (compact, top-N for the branch detail) ──────

    /** 🔴 Top bleeding items (lost sales) at the branch. */
    public function bleedingItems(string $warehouseCode, int $limit = 6): array
    {
        $rows = DB::table('branch_product_intelligence')
            ->where('warehouse_code', $warehouseCode)
            ->whereIn('health_status', ['starved', 'stockout', 'low'])
            ->orderByDesc(DB::raw('lost_sales_monthly * COALESCE(unit_retail_sar, unit_cost_sar / 0.6, 0)'))
            ->orderBy('days_of_cover')
            ->limit($limit)
            ->get();

        $meta = $this->productMeta($rows->pluck('item_code')->all());

        return $rows->map(function ($r) use ($meta) {
            $unitRevenue = $r->unit_retail_sar !== null
                ? (float) $r->unit_retail_sar
                : ($r->unit_cost_sar !== null ? (float) $r->unit_cost_sar / 0.6 : 0.0);
            return [
                'item_code' => $r->item_code,
                'name' => $meta[$r->item_code]['name'] ?? $r->item_code,
                'image_url' => $meta[$r->item_code]['image_url'] ?? $this->imageUrl($r->item_code),
                'health_status' => $r->health_status,
                'current_stock' => (float) $r->current_stock,
                'lost_sales_monthly' => (float) $r->lost_sales_monthly,
                'lost_revenue_monthly' => round((float) $r->lost_sales_monthly * $unitRevenue, 2),
            ];
        })->all();
    }

    /** 🟡 Top trapped-capital items at the branch. */
    public function trappedItems(string $warehouseCode, int $limit = 6): array
    {
        $rows = DB::table('branch_product_intelligence')
            ->where('warehouse_code', $warehouseCode)
            ->whereIn('health_status', ['overstock', 'dead'])
            ->where('capital_at_risk_sar', '>', 0)
            ->orderByDesc('capital_at_risk_sar')
            ->limit($limit)
            ->get();

        $meta = $this->productMeta($rows->pluck('item_code')->all());

        return $rows->map(fn ($r) => [
            'item_code' => $r->item_code,
            'name' => $meta[$r->item_code]['name'] ?? $r->item_code,
            'image_url' => $meta[$r->item_code]['image_url'] ?? $this->imageUrl($r->item_code),
            'health_status' => $r->health_status,
            'current_stock' => (float) $r->current_stock,
            'excess_units' => (float) $r->excess_units,
            'capital_at_risk_sar' => (float) $r->capital_at_risk_sar,
        ])->all();
    }

    // ─── Shared helpers ──────────────────────────────────────────

    /** item_code => ['name','image_url'] (Arabic name, falling back to item_name). */
    public function productMeta(array $codes): array
    {
        if (empty($codes)) {
            return [];
        }
        return DB::table('products')
            ->whereIn('item_code', $codes)
            ->get(['item_code', 'zb_name_ar', 'item_name'])
            ->mapWithKeys(fn ($p) => [$p->item_code => [
                'name' => $p->zb_name_ar ?: ($p->item_name ?: $p->item_code),
                'image_url' => $this->imageUrl($p->item_code),
            ]])
            ->all();
    }

    /** Product image URL — same pattern the counting/scan/pulse screens render. */
    public function imageUrl(string $code): string
    {
        return 'https://ppte.sa/imghd/' . substr($code, 0, 4) . '/' . $code . '.png';
    }
}
