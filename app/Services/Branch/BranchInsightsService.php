<?php

namespace App\Services\Branch;

use App\Models\InventoryCounting;
use App\Models\QualityTaskInstance;
use App\Models\StockTransfer;
use App\Models\Warehouse;
use App\Models\ZooboxiOrder;
use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
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

    /** Sales channels the dashboards can slice by. */
    public const CHANNELS = ['retail', 'wholesale', 'total'];

    /**
     * SQL predicate + bindings for a sales channel on a header table alias.
     *   retail    → card_code = C0000001 (the showroom cash register)
     *   wholesale → card_code <> C0000001 (any real B2B customer)
     *   total     → card_code IS NOT NULL
     * NULL card_code docs are excluded from every channel, so
     * total ≡ retail + wholesale exactly.
     *
     * @return array{0: string, 1: array}
     */
    private function channelPredicate(string $channel, string $alias = 'i'): array
    {
        return match ($channel) {
            'wholesale' => ["{$alias}.card_code <> ? AND {$alias}.card_code IS NOT NULL", [self::RETAIL_CARD]],
            'total' => ["{$alias}.card_code IS NOT NULL", []],
            default => ["{$alias}.card_code = ?", [self::RETAIL_CARD]],
        };
    }

    /**
     * A bleeding item whose NET available-to-sell (in_stock − committed) summed
     * across every warehouse is below this can't be fixed by moving stock around —
     * it needs a fresh supplier order (OOS). At or above it, stock exists somewhere
     * in the network and the remedy is a transfer. Public so the product-detail
     * endpoint gates its transfer suggestion on the same threshold.
     */
    public const OOS_NET_AVAILABLE_THRESHOLD = 100;

    /**
     * Central feeder warehouses (mirror of the smart-transfer engine). These plus
     * the selling showrooms make up the sellable RETAIL network; everything else
     * (ShipGo, damaged/expired, Amazon, government, head office…) is excluded from
     * availability and transfer sourcing.
     */
    public const CENTRAL_WAREHOUSES = ['AGL001', '3PL001', 'STL001', 'STL002'];

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
     * Accepts: today | week | month (default) | year | custom (with from/to).
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
            case 'year':
                return [$today->copy()->startOfYear(), $today->copy()->endOfDay(), 'year'];
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
                SELECT h.id, MAX(h.doc_total / 1.15) doc_total, MIN(l.warehouse_code) warehouse_code
                FROM {$headerTable} h JOIN {$lineTable} l ON l.{$fk} = h.id
                WHERE h.card_code = ? AND h.doc_date BETWEEN ? AND ? AND h.cancelled = 'N'
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
     * scoped to one warehouse and/or a sales channel (retail/wholesale/total).
     * Continuous buckets — gaps filled with zero.
     *
     * @return array{granularity:string, points: array<int, array{label:string, sales:float, profit:float}>}
     */
    public function salesProfitTrend(Carbon $start, Carbon $end, string $granularity, ?string $warehouseCode = null, string $channel = 'retail'): array
    {
        // SALES come from the invoice HEADER total (doc_total) — present for every
        // month, and on the same basis as the net-sales KPI — so the whole year is
        // always visible, even for months whose line economics aren't enriched yet.
        // PROFIT comes from the enriched line data (gross_profit) where available.
        $wh = $warehouseCode;
        [$card, $cardBind] = $this->channelPredicate($channel);
        $bind = array_merge($cardBind, [$start->toDateTimeString(), $end->toDateTimeString()]);

        // Bucket expression for the (header-based) sales query and (line-based) profit query.
        [$hb, $lb] = match ($granularity) {
            'hour' => ['HOUR(i.doc_time)', 'HOUR(i.doc_time)'],
            'month' => ["DATE_FORMAT(i.doc_date, '%Y-%m')", "DATE_FORMAT(i.doc_date, '%Y-%m')"],
            default => ['DATE(i.doc_date)', 'DATE(i.doc_date)'],
        };
        $timeGuard = $granularity === 'hour' ? ' AND i.doc_time IS NOT NULL' : '';

        // ── Sales: one doc_total per invoice, bucketed. Overview = fast header-only
        //    scan; branch view de-dupes per invoice to attribute a warehouse. ──
        if ($wh === null) {
            $salesSql = "SELECT {$hb} k, SUM(i.doc_total / 1.15) v FROM sap_invoices i
                WHERE {$card} AND i.doc_date BETWEEN ? AND ? AND i.cancelled = 'N'{$timeGuard} GROUP BY k";
            $salesBind = $bind;
        } else {
            $tg = $granularity === 'hour' ? ' AND t.doc_time IS NOT NULL' : '';
            $tb = str_replace('i.', 't.', $hb);
            $salesSql = "SELECT {$tb} k, SUM(t.doc_total) v FROM (
                    SELECT i.id, MAX(i.doc_total / 1.15) doc_total, MAX(i.doc_date) doc_date, MAX(i.doc_time) doc_time, MIN(l.warehouse_code) warehouse_code
                    FROM sap_invoices i JOIN sap_invoice_lines l ON l.sap_invoice_id = i.id
                    WHERE {$card} AND i.doc_date BETWEEN ? AND ? AND i.cancelled = 'N'
                    GROUP BY i.id
                ) t WHERE t.warehouse_code = ?{$tg} GROUP BY k";
            $salesBind = array_merge($bind, [$wh]);
        }
        $salesRows = collect(DB::select($salesSql, $salesBind))->keyBy('k');

        // ── Profit: summed line gross_profit (where enriched), bucketed. ──
        $profitSql = "SELECT {$lb} k, SUM(l.gross_profit) v
            FROM sap_invoice_lines l JOIN sap_invoices i ON i.id = l.sap_invoice_id
            WHERE {$card} AND i.doc_date BETWEEN ? AND ? AND l.gross_profit IS NOT NULL"
            . ($wh !== null ? ' AND l.warehouse_code = ?' : '') . $timeGuard . " GROUP BY k";
        $profitBind = $wh !== null ? array_merge($bind, [$wh]) : $bind;
        $profitRows = collect(DB::select($profitSql, $profitBind))->keyBy('k');

        // ── Returns: credit memos netted off so the chart matches the net-sales
        //    KPI. Memos carry no doc_time, so hourly buckets can't absorb them —
        //    hourly returns ship unbucketed for the client to net in totals. ──
        [$mCard, $mCardBind] = $this->channelPredicate($channel, 'm');
        $mBind = array_merge($mCardBind, [$start->toDateTimeString(), $end->toDateTimeString()]);
        $memoRows = collect();
        $memoProfitRows = collect();
        $returnsUnbucketed = 0.0;
        $returnsProfitUnbucketed = 0.0;

        $memoProfitSql = "SELECT %s SUM(l.gross_profit) v
            FROM sap_credit_memo_lines l JOIN sap_credit_memos m ON m.id = l.sap_credit_memo_id
            WHERE {$mCard} AND m.doc_date BETWEEN ? AND ? AND m.cancelled = 'N' AND l.gross_profit IS NOT NULL"
            . ($wh !== null ? ' AND l.warehouse_code = ?' : '') . ' %s';
        $memoProfitBind = $wh !== null ? array_merge($mBind, [$wh]) : $mBind;

        if ($granularity === 'hour') {
            if ($wh === null) {
                $returnsUnbucketed = (float) (DB::selectOne("SELECT SUM(m.doc_total / 1.15) v FROM sap_credit_memos m
                    WHERE {$mCard} AND m.doc_date BETWEEN ? AND ? AND m.cancelled = 'N'", $mBind)->v ?? 0);
            } else {
                $returnsUnbucketed = (float) (DB::selectOne("SELECT SUM(t.doc_total) v FROM (
                        SELECT m.id, MAX(m.doc_total / 1.15) doc_total, MIN(l.warehouse_code) warehouse_code
                        FROM sap_credit_memos m JOIN sap_credit_memo_lines l ON l.sap_credit_memo_id = m.id
                        WHERE {$mCard} AND m.doc_date BETWEEN ? AND ? AND m.cancelled = 'N' GROUP BY m.id
                    ) t WHERE t.warehouse_code = ?", array_merge($mBind, [$wh]))->v ?? 0);
            }
            $returnsProfitUnbucketed = (float) (DB::selectOne(sprintf($memoProfitSql, '', ''), $memoProfitBind)->v ?? 0);
        } else {
            $mb = str_replace('i.', 'm.', $hb);
            if ($wh === null) {
                $memoRows = collect(DB::select("SELECT {$mb} k, SUM(m.doc_total / 1.15) v FROM sap_credit_memos m
                    WHERE {$mCard} AND m.doc_date BETWEEN ? AND ? AND m.cancelled = 'N' GROUP BY k", $mBind))->keyBy('k');
            } else {
                $tb = str_replace('i.', 't.', $hb);
                $memoRows = collect(DB::select("SELECT {$tb} k, SUM(t.doc_total) v FROM (
                        SELECT m.id, MAX(m.doc_total / 1.15) doc_total, MAX(m.doc_date) doc_date, MIN(l.warehouse_code) warehouse_code
                        FROM sap_credit_memos m JOIN sap_credit_memo_lines l ON l.sap_credit_memo_id = m.id
                        WHERE {$mCard} AND m.doc_date BETWEEN ? AND ? AND m.cancelled = 'N' GROUP BY m.id
                    ) t WHERE t.warehouse_code = ? GROUP BY k", array_merge($mBind, [$wh])))->keyBy('k');
            }
            $lbm = str_replace('i.', 'm.', $lb);
            $memoProfitRows = collect(DB::select(sprintf($memoProfitSql, "{$lbm} k,", 'GROUP BY k'), $memoProfitBind))->keyBy('k');
        }

        $point = fn ($key, $label) => [
            'label' => $label,
            'sales' => round((float) ($salesRows[$key]->v ?? 0) - (float) ($memoRows[$key]->v ?? 0), 2),
            'profit' => round((float) ($profitRows[$key]->v ?? 0) - (float) ($memoProfitRows[$key]->v ?? 0), 2),
        ];

        if ($granularity === 'hour') {
            $hours = $salesRows->keys()->map(fn ($h) => (int) $h)->all();
            if (empty($hours)) {
                return ['granularity' => 'hour', 'points' => []];
            }
            $lo = max(0, min($hours));
            $hi = min(23, max($hours));
            $points = [];
            for ($h = $lo; $h <= $hi; $h++) {
                $points[] = $point($h, sprintf('%02d:00', $h));
            }
            return [
                'granularity' => 'hour',
                'points' => $points,
                'returns' => round($returnsUnbucketed, 2),
                'returns_profit' => round($returnsProfitUnbucketed, 2),
            ];
        }

        if ($granularity === 'month') {
            $points = [];
            $cursor = $start->copy()->startOfMonth();
            $last = $end->copy()->startOfMonth();
            $guard = 0;
            while ($cursor->lte($last) && $guard < 24) {
                $key = $cursor->format('Y-m');
                $points[] = $point($key, $key);
                $cursor->addMonth();
                $guard++;
            }
            return ['granularity' => 'month', 'points' => $points];
        }

        $points = [];
        $cursor = $start->copy()->startOfDay();
        $last = $end->copy()->startOfDay();
        $guard = 0;
        while ($cursor->lte($last) && $guard < 120) {
            $key = $cursor->toDateString();
            $points[] = $point($key, $key);
            $cursor->addDay();
            $guard++;
        }
        return ['granularity' => 'day', 'points' => $points];
    }

    /**
     * Retail vs wholesale vs total money blocks over a period, on the HEADER
     * basis (doc_total): gross & invoice count from sap_invoices, returns from
     * sap_credit_memos, profit from the enriched line gross_profit net of
     * credit-memo lines. Four grouped scans total, all index-backed.
     *
     * Note: the retail block here is header-based and can differ slightly from
     * the branch-summed retail totals (docs with no lines / NULL-warehouse
     * lines aren't attributable to a branch) — that gap is deliberate.
     *
     * @return array<string, array{gross:float, returns:float, net:float, invoices:int, profit:float}>
     */
    public function channelTotals(Carbon $start, Carbon $end): array
    {
        $bind = [self::RETAIL_CARD, $start->toDateTimeString(), $end->toDateTimeString()];
        $bucket = "CASE WHEN card_code = ? THEN 'retail' ELSE 'wholesale' END";

        $inv = collect(DB::select(
            "SELECT {$bucket} ch, SUM(doc_total / 1.15) gross, COUNT(*) invoices FROM sap_invoices
             WHERE card_code IS NOT NULL AND cancelled = 'N' AND doc_date BETWEEN ? AND ? GROUP BY ch", $bind))->keyBy('ch');
        $ret = collect(DB::select(
            "SELECT {$bucket} ch, SUM(doc_total / 1.15) r FROM sap_credit_memos
             WHERE card_code IS NOT NULL AND cancelled = 'N' AND doc_date BETWEEN ? AND ? GROUP BY ch", $bind))->keyBy('ch');
        $gp = collect(DB::select(
            "SELECT CASE WHEN i.card_code = ? THEN 'retail' ELSE 'wholesale' END ch, SUM(l.gross_profit) p
             FROM sap_invoice_lines l JOIN sap_invoices i ON i.id = l.sap_invoice_id
             WHERE i.card_code IS NOT NULL AND i.doc_date BETWEEN ? AND ? AND l.gross_profit IS NOT NULL
             GROUP BY ch", $bind))->keyBy('ch');
        $gpRet = collect(DB::select(
            "SELECT CASE WHEN m.card_code = ? THEN 'retail' ELSE 'wholesale' END ch, SUM(l.gross_profit) p
             FROM sap_credit_memo_lines l JOIN sap_credit_memos m ON m.id = l.sap_credit_memo_id
             WHERE m.card_code IS NOT NULL AND m.doc_date BETWEEN ? AND ? AND l.gross_profit IS NOT NULL
             GROUP BY ch", $bind))->keyBy('ch');

        $out = [];
        foreach (['retail', 'wholesale'] as $ch) {
            $gross = (float) ($inv[$ch]->gross ?? 0);
            $returns = (float) ($ret[$ch]->r ?? 0);
            $out[$ch] = [
                'gross' => round($gross, 2),
                'returns' => round($returns, 2),
                'net' => round($gross - $returns, 2),
                'invoices' => (int) ($inv[$ch]->invoices ?? 0),
                'profit' => round((float) ($gp[$ch]->p ?? 0) - (float) ($gpRet[$ch]->p ?? 0), 2),
            ];
        }
        $out['total'] = [
            'gross' => round($out['retail']['gross'] + $out['wholesale']['gross'], 2),
            'returns' => round($out['retail']['returns'] + $out['wholesale']['returns'], 2),
            'net' => round($out['retail']['net'] + $out['wholesale']['net'], 2),
            'invoices' => $out['retail']['invoices'] + $out['wholesale']['invoices'],
            'profit' => round($out['retail']['profit'] + $out['wholesale']['profit'], 2),
        ];
        return $out;
    }

    /**
     * Top wholesale customers by net sales (invoices − credit memos, header
     * doc_total) over a period — the wholesale channel's natural leaderboard
     * (branch attribution is meaningless for multi-warehouse B2B docs).
     * Profit/margin come from enriched lines, fetched only for the top codes.
     * Names resolve via customers.card_name; the sync covers only portal
     * customers, so falling back to the raw card_code is expected.
     *
     * @return array{customers_count:int, customers: array<int, array<string, mixed>>}
     */
    public function wholesaleCustomers(Carbon $start, Carbon $end, int $limit = 15): array
    {
        [$card, $cardBind] = $this->channelPredicate('wholesale');
        $bind = array_merge($cardBind, [$start->toDateTimeString(), $end->toDateTimeString()]);

        $sales = collect(DB::select(
            "SELECT i.card_code, SUM(i.doc_total / 1.15) gross, COUNT(*) invoices FROM sap_invoices i
             WHERE {$card} AND i.cancelled = 'N' AND i.doc_date BETWEEN ? AND ? GROUP BY i.card_code", $bind))->keyBy('card_code');
        [$mcard, $mBind] = $this->channelPredicate('wholesale', 'm');
        $memos = collect(DB::select(
            "SELECT m.card_code, SUM(m.doc_total / 1.15) r, COUNT(*) c FROM sap_credit_memos m
             WHERE {$mcard} AND m.cancelled = 'N' AND m.doc_date BETWEEN ? AND ? GROUP BY m.card_code",
            array_merge($mBind, [$start->toDateTimeString(), $end->toDateTimeString()])))->keyBy('card_code');

        // Merge → net per customer → top N.
        $rows = [];
        foreach ($sales as $code => $s) {
            $returns = (float) ($memos[$code]->r ?? 0);
            $rows[$code] = [
                'card_code' => $code,
                'gross' => (float) $s->gross,
                'returns' => $returns,
                'net' => (float) $s->gross - $returns,
                'invoices' => (int) $s->invoices,
                'returns_count' => (int) ($memos[$code]->c ?? 0),
            ];
        }
        foreach ($memos as $code => $m) {
            if (!isset($rows[$code])) {
                $rows[$code] = [
                    'card_code' => $code, 'gross' => 0.0, 'returns' => (float) $m->r,
                    'net' => -(float) $m->r, 'invoices' => 0, 'returns_count' => (int) $m->c,
                ];
            }
        }
        $customersCount = count($rows);
        usort($rows, fn ($a, $b) => $b['net'] <=> $a['net']);
        $top = array_slice($rows, 0, $limit);
        $codes = array_column($top, 'card_code');

        // Line economics + names only for the visible customers.
        $econ = empty($codes) ? collect() : collect(DB::select(
            "SELECT i.card_code, SUM(l.gross_profit) p, SUM(l.line_revenue) rev
             FROM sap_invoice_lines l JOIN sap_invoices i ON i.id = l.sap_invoice_id
             WHERE i.card_code IN (" . implode(',', array_fill(0, count($codes), '?')) . ")
               AND i.doc_date BETWEEN ? AND ? AND l.gross_profit IS NOT NULL
             GROUP BY i.card_code",
            array_merge($codes, [$start->toDateTimeString(), $end->toDateTimeString()])))->keyBy('card_code');
        $names = empty($codes) ? collect() : DB::table('customers')
            ->whereIn('card_code', $codes)->pluck('card_name', 'card_code');

        $customers = array_map(function ($r) use ($econ, $names) {
            $e = $econ[$r['card_code']] ?? null;
            $profit = $e ? (float) $e->p : 0.0;
            $rev = $e ? (float) $e->rev : 0.0;
            return [
                'card_code' => $r['card_code'],
                'name' => ($names[$r['card_code']] ?? null) ?: $r['card_code'],
                'gross' => round($r['gross'], 2),
                'returns' => round($r['returns'], 2),
                'net' => round($r['net'], 2),
                'invoices' => $r['invoices'],
                'returns_count' => $r['returns_count'],
                'profit' => round($profit, 2),
                'margin_pct' => $rev > 0 ? round($profit / $rev * 100, 1) : null,
            ];
        }, $top);

        return ['customers_count' => $customersCount, 'customers' => $customers];
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
        // Each sold line is valued at its catalog retail and weighted by its own
        // per-item margin; outlier costs (margin outside 2%..70%) are dropped from
        // the blend. The whole weighting is done in SQL so only one row per
        // warehouse crosses into PHP — same result as the old per-item loop, ~3x
        // faster over a full year.
        $rows = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->join('branch_product_intelligence as b', function ($j) {
                $j->on('b.item_code', '=', 'l.item_code')->on('b.warehouse_code', '=', 'l.warehouse_code');
            })
            ->where('i.card_code', self::RETAIL_CARD)
            ->whereBetween('i.doc_date', [$start, $end])
            ->where('b.unit_retail_sar', '>', 0)
            ->where('b.unit_cost_sar', '>', 0)
            ->whereRaw('(1 - b.unit_cost_sar / b.unit_retail_sar) BETWEEN 0.02 AND 0.70')
            ->groupBy('l.warehouse_code')
            ->select(
                'l.warehouse_code',
                DB::raw('SUM(l.quantity * b.unit_retail_sar) rev'),
                DB::raw('SUM(l.quantity * b.unit_retail_sar * (1 - b.unit_cost_sar / b.unit_retail_sar)) profit')
            )
            ->get();

        $out = [];
        foreach ($rows as $r) {
            if ((float) $r->rev > 0) {
                $out[$r->warehouse_code] = (float) $r->profit / (float) $r->rev;
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
                SELECT i.id, MAX(i.doc_total / 1.15) doc_total, MAX(i.doc_date) doc_date, MIN(l.warehouse_code) warehouse_code
                FROM sap_invoices i JOIN sap_invoice_lines l ON l.sap_invoice_id = i.id
                WHERE i.card_code = ? AND i.cancelled = 'N' AND i.doc_date BETWEEN ? AND ?
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
        $net = $this->transferableSupply($rows->pluck('item_code')->all(), $warehouseCode);

        return $rows->map(function ($r) use ($meta, $net) {
            $unitRevenue = $r->unit_retail_sar !== null
                ? (float) $r->unit_retail_sar
                : ($r->unit_cost_sar !== null ? (float) $r->unit_cost_sar / 0.6 : 0.0);
            $available = $net[$r->item_code]['surplus'] ?? 0.0;
            $onOrder = $net[$r->item_code]['on_order'] ?? 0.0;
            // No real surplus to move (no central stock and no surplus showroom) →
            // order from the supplier (OOS); otherwise a surplus source exists → transfer.
            $isOos = $available < self::OOS_NET_AVAILABLE_THRESHOLD;
            return [
                'item_code' => $r->item_code,
                'name' => $meta[$r->item_code]['name'] ?? $r->item_code,
                'image_url' => $meta[$r->item_code]['image_url'] ?? $this->imageUrl($r->item_code),
                'health_status' => $r->health_status,
                'current_stock' => (float) $r->current_stock,
                'lost_sales_monthly' => (float) $r->lost_sales_monthly,
                'lost_revenue_monthly' => round((float) $r->lost_sales_monthly * $unitRevenue, 2),
                'net_available' => round($available, 2),
                'on_order' => round($onOrder, 2),
                'remedy' => $isOos ? 'reorder' : 'transfer',
                'oos' => $isOos,
            ];
        })->all();
    }

    /**
     * Warehouse codes of the sellable RETAIL network — the selling showrooms
     * (derived from actual retail sales) plus the central feeder warehouses.
     * Mirrors the smart-transfer engine: ShipGo, damaged/expired, Amazon,
     * government and other non-retail warehouses are NOT counted toward
     * availability or offered as transfer sources. Cached briefly (the showroom
     * set changes rarely).
     *
     * @return array<int, string>
     */
    public function retailNetworkCodes(): array
    {
        return Cache::remember('retail_network_codes', 1800, fn () => array_values(array_unique(array_merge(
            self::CENTRAL_WAREHOUSES,
            $this->exhibitions()->keys()->all()
        ))));
    }

    /**
     * Transferable SURPLUS per item — the stock the retail network can actually
     * spare to fix a stockout at [$target], summed as:
     *   • central warehouses → all their net available (in_stock − committed), and
     *   • other showrooms → only their EXCESS (stock beyond their own needs),
     * so a transfer never robs a showroom that still needs the item. When this is
     * below the threshold the remedy is a supplier order (OOS); otherwise a surplus
     * source exists and the remedy is a transfer. Also returns on-order qty (across
     * the retail network) for the "قيد الطلب" flag.
     *
     * @param  array<int,string>  $itemCodes
     * @return array<string, array{surplus: float, central_net: float, showroom_excess: float, on_order: float}>
     */
    private function transferableSupply(array $itemCodes, string $target): array
    {
        $itemCodes = array_values(array_unique(array_filter($itemCodes)));
        if (empty($itemCodes)) {
            return [];
        }

        $central = self::CENTRAL_WAREHOUSES;
        $showrooms = array_values(array_diff($this->retailNetworkCodes(), $central));

        // Central: all net available is spare (central exists to distribute).
        $centralNet = DB::table('warehouse_item_stocks')
            ->whereIn('item_code', $itemCodes)
            ->whereIn('warehouse_code', $central)
            ->groupBy('item_code')
            ->select('item_code', DB::raw('SUM(GREATEST(in_stock - committed, 0)) v'))
            ->get()->keyBy('item_code');

        // Other showrooms: only their surplus (excess_units), never their needed stock.
        $showroomExcess = collect();
        if (!empty($showrooms)) {
            $showroomExcess = DB::table('branch_product_intelligence')
                ->whereIn('item_code', $itemCodes)
                ->whereIn('warehouse_code', $showrooms)
                ->where('warehouse_code', '!=', $target)
                ->where('excess_units', '>', 0)
                ->groupBy('item_code')
                ->select('item_code', DB::raw('SUM(excess_units) v'))
                ->get()->keyBy('item_code');
        }

        // On order across the retail network (a live supplier PO is incoming).
        $onOrder = DB::table('warehouse_item_stocks')
            ->whereIn('item_code', $itemCodes)
            ->whereIn('warehouse_code', $this->retailNetworkCodes())
            ->groupBy('item_code')
            ->select('item_code', DB::raw('SUM(ordered) v'))
            ->get()->keyBy('item_code');

        $out = [];
        foreach ($itemCodes as $code) {
            $cn = (float) ($centralNet[$code]->v ?? 0);
            $se = (float) ($showroomExcess[$code]->v ?? 0);
            $out[$code] = [
                'surplus' => $cn + $se,
                'central_net' => $cn,
                'showroom_excess' => $se,
                'on_order' => (float) ($onOrder[$code]->v ?? 0),
            ];
        }
        return $out;
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
