<?php

namespace App\Services\Inventory;

use App\Models\BranchGapTransferRequest;
use App\Services\Branch\BranchInsightsService;
use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * «عجز الفروع» — the items that sell well (showrooms on register C0000001 and
 * ShipGo online) but are thin at one branch, and how many another warehouse
 * can spare for it.
 *
 * All figures are pieces. Reads the local mirrors only (sales, stock, transfer
 * requests); writing the request to SAP is TransferRequestWriter's job.
 */
class BranchGapService
{
    public const RETAIL_CARD = 'C0000001';

    public const DEFAULT_TARGET = 'RUH010';

    public const DEFAULT_SOURCE = 'RUH002';

    /** ShipGo e-commerce warehouses: their invoices are the online demand. */
    public const ONLINE_WAREHOUSES = ['RUH003', 'JED001', 'UZH002'];

    /** Never left below this on a showroom shelf, either side of a transfer. */
    public const MIN_SHELF = 3;

    /**
     * @param  array{target?:string, source?:string, window?:int, cover?:int, keep?:int, online_share?:int, min_monthly?:int}  $opts
     * @return array{params: array, rows: array<int, array>, totals: array, online_until: ?string, generated_at: string}
     */
    public function analyse(array $opts = []): array
    {
        $p = $this->params($opts);
        $key = 'branch-gaps:v3:' . md5(json_encode($p));

        return Cache::remember($key, 600, fn () => $this->compute($p));
    }

    /** Drops every cached pass (after a request, so its lines count as on the way). */
    public function forget(): void
    {
        Cache::forever('branch-gaps:epoch', (int) Cache::get('branch-gaps:epoch', 0) + 1);
    }

    /** @return array<string, int|string> */
    public function params(array $o): array
    {
        $pick = fn ($v, array $allowed, $default) => in_array((int) $v, $allowed, true) ? (int) $v : $default;

        return [
            'target' => strtoupper((string) ($o['target'] ?? self::DEFAULT_TARGET)) ?: self::DEFAULT_TARGET,
            'source' => strtoupper((string) ($o['source'] ?? self::DEFAULT_SOURCE)) ?: self::DEFAULT_SOURCE,
            'window' => $pick($o['window'] ?? 90, [30, 60, 90], 90),
            'cover' => $pick($o['cover'] ?? 14, [7, 14, 21, 30], 14),
            'keep' => $pick($o['keep'] ?? 30, [14, 30, 45, 60], 30),
            'online_share' => $pick($o['online_share'] ?? 10, [0, 5, 10, 20, 30], 10),
            'min_monthly' => $pick($o['min_monthly'] ?? 20, [5, 10, 20, 40, 80], 20),
            'epoch' => (int) Cache::get('branch-gaps:epoch', 0),
        ];
    }

    /** Warehouses offered as a source: Riyadh showrooms + the central feeders. */
    public function sourceOptions(string $target): array
    {
        $codes = array_merge(
            ['RUH002', 'RUH004', 'RUH005', 'RUH006', 'RUH007', 'RUH008'],
            BranchInsightsService::CENTRAL_WAREHOUSES,
            ['RUH003'],
        );

        return collect($codes)
            ->reject(fn ($c) => $c === $target)
            ->mapWithKeys(fn ($c) => [$c => self::warehouseLabel($c)])
            ->all();
    }

    public static function warehouseLabel(string $code): string
    {
        $names = BranchInsightsService::AR_NAMES + [
            'STL001' => 'ستارلينكس · الرياض',
            'STL002' => 'ستارلينكس · جدة',
            'AGL001' => 'أجيليتي · الرياض',
            '3PL001' => 'أجكس 3PL',
            'RUH003' => 'شيب قو · الرياض',
            'JED001' => 'شيب قو · جدة',
            'UZH002' => 'شيب قو · عنيزة',
        ];

        return $names[$code] ?? $code;
    }

    // ─── The pass ────────────────────────────────────────────────

    private function compute(array $p): array
    {
        $target = $p['target'];
        $source = $p['source'];
        $W = $p['window'];
        $end = Carbon::today();
        $start = $end->copy()->subDays($W - 1);

        // 1. Showroom sales (register C0000001), net of returns, per item × warehouse.
        $retail = $this->netByItemWarehouse(
            fn ($q, $h) => $q->where("$h.card_code", self::RETAIL_CARD),
            $start, $end,
        );

        // 2. ShipGo online: invoices posted from the ShipGo warehouses (store
        //    reports arrive monthly, so the window ends at the latest one).
        $onlineUntil = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->whereIn('l.warehouse_code', self::ONLINE_WAREHOUSES)
            ->where('i.cancelled', 'N')
            ->where('i.doc_date', '>=', $end->copy()->subDays(120)->toDateString())
            ->max('i.doc_date');
        $onlineEnd = $onlineUntil ? Carbon::parse($onlineUntil)->startOfDay() : $end->copy();
        $online = $this->netByItemWarehouse(
            fn ($q, $h) => $q->whereIn('l.warehouse_code', self::ONLINE_WAREHOUSES)->where("$h.card_code", '<>', self::RETAIL_CARD),
            $onlineEnd->copy()->subDays($W - 1), $onlineEnd,
        );

        // Riyadh showrooms that sold anything in the window: the "typical Riyadh branch".
        $riyadh = collect($retail)->flatMap(fn ($byWh) => array_keys($byWh))->unique()
            ->filter(fn ($c) => str_starts_with($c, 'RUH') && $c !== $target && ! in_array($c, self::ONLINE_WAREHOUSES, true))
            ->values()->all();
        $riyadhCount = max(1, count($riyadh));

        // The target may be younger than the window (RUH010 opened 2026-07-23).
        $firstSale = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('l.warehouse_code', $target)
            ->where('i.card_code', self::RETAIL_CARD)
            ->where('i.doc_date', '>=', $start->toDateString())
            ->min('i.doc_date');
        $targetDays = $firstSale ? max(14, Carbon::parse($firstSale)->diffInDays($end) + 1) : $W;
        $targetDays = min($W, $targetDays);

        $codes = array_values(array_unique(array_merge(array_keys($retail), array_keys($online))));
        if (empty($codes)) {
            return $this->result($p, [], $onlineUntil);
        }

        // 3. Stock at the target, the source and every other candidate source.
        $candidates = array_keys($this->sourceOptions($target));
        $stock = [];
        foreach (array_chunk($codes, 800) as $chunk) {
            DB::table('warehouse_item_stocks')
                ->whereIn('item_code', $chunk)
                ->whereIn('warehouse_code', array_values(array_unique(array_merge([$target, $source], $candidates))))
                ->get(['item_code', 'warehouse_code', 'in_stock', 'committed'])
                ->each(function ($r) use (&$stock) {
                    $stock[$r->item_code][$r->warehouse_code] = [
                        'on_hand' => (float) $r->in_stock,
                        'available' => max(0.0, (float) $r->in_stock - (float) $r->committed),
                    ];
                });
        }

        // 4. Already on the way to the target (open SAP transfer requests).
        $onWay = $this->openRequestsTo($target);

        // 5. What each item brings into the basket (showroom invoices, same window).
        $basket = $this->basketStats($start, $end);

        $meta = $this->productMeta($codes);
        $minDaily = $p['min_monthly'] / 30;
        $rows = [];

        foreach ($codes as $code) {
            $byWh = $retail[$code] ?? [];
            $showQty = array_sum(array_column($byWh, 'qty'));
            $showRev = array_sum(array_column($byWh, 'rev'));
            $onlineQty = array_sum(array_column($online[$code] ?? [], 'qty'));
            $showDaily = max(0, $showQty) / $W;
            $onlineDaily = max(0, $onlineQty) / $W;

            if ($showDaily + $onlineDaily < $minDaily) {
                continue;
            }

            $ownDaily = max(0, $byWh[$target]['qty'] ?? 0) / $targetDays;
            $riyadhQty = 0.0;
            foreach ($riyadh as $wh) {
                $riyadhQty += max(0, $byWh[$wh]['qty'] ?? 0);
            }
            $benchDaily = $riyadhQty / $riyadhCount / $W;
            $estDaily = max($ownDaily, $benchDaily) + $onlineDaily * $p['online_share'] / 100;

            $goal = (int) max(self::MIN_SHELF, ceil($estDaily * $p['cover']));
            $onHand = (float) ($stock[$code][$target]['on_hand'] ?? 0);
            $coming = (float) ($onWay[$code] ?? 0);
            $gap = (int) max(0, ceil($goal - $onHand - $coming));
            if ($gap <= 0) {
                continue;
            }

            // A warehouse's own pace: showroom sales, and for ShipGo its online orders too.
            $pace = fn (string $wh) => ($byWh[$wh]['qty'] ?? 0)
                + (in_array($wh, self::ONLINE_WAREHOUSES, true) ? ($online[$code][$wh]['qty'] ?? 0) : 0);

            $spare = $this->spare($stock[$code][$source]['available'] ?? 0, $pace($source), $source, $p);
            $suggest = (int) min($gap, $spare);

            // Best other place to take it from, for items the chosen source can't cover.
            $alt = null;
            foreach ($candidates as $wh) {
                if ($wh === $source) {
                    continue;
                }
                $s = $this->spare($stock[$code][$wh]['available'] ?? 0, $pace($wh), $wh, $p);
                if ($s > 0 && ($alt === null || $s > $alt['spare'])) {
                    $alt = ['code' => $wh, 'name' => self::warehouseLabel($wh), 'spare' => $s];
                }
            }

            $price = $showQty > 0 ? $showRev / $showQty : 0.0;

            // Lost in the next 30 days if nothing is done: the days the shelf
            // stands empty once stock and what is on the way run out.
            $lostDays = $estDaily > 0 ? max(0.0, 30 - ($onHand + $coming) / $estDaily) : 0.0;
            $lostPcs = $estDaily * $lostDays;

            // Basket effect (estimate): invoices where this item is the biggest
            // line are visits made for it; their other lines may leave with it.
            $b = $basket[$code] ?? null;
            $haloPerDoc = $b && $b['docs'] > 0 ? $b['halo'] / $b['docs'] : 0.0;
            $pcsPerDoc = $b && $b['docs'] > 0 && $b['qty'] > 0 ? $b['qty'] / $b['docs'] : 1.0;
            $lostDocs = $lostPcs / $pcsPerDoc;
            $sellingBranches = count(array_filter($byWh, fn ($v, $wh) => $v['qty'] > 0 && ! in_array($wh, self::ONLINE_WAREHOUSES, true), ARRAY_FILTER_USE_BOTH));

            $rows[] = [
                'code' => $code,
                'name' => $meta[$code]['name'] ?? $code,
                'barcode' => $meta[$code]['barcode'] ?? null,
                'pets' => $meta[$code]['pets'] ?? [],
                'depts' => $meta[$code]['depts'] ?? [],
                'brand' => $meta[$code]['brand'] ?? null,
                'image' => 'https://ppte.sa/imghd/' . substr($code, 0, 4) . '/' . $code . '.png',
                'show_month' => round($showDaily * 30, 1),
                'online_month' => round($onlineDaily * 30, 1),
                'branches' => $sellingBranches,
                'own_month' => round($ownDaily * 30, 1),
                'bench_month' => round($benchDaily * 30, 1),
                'est_month' => round($estDaily * 30, 1),
                'on_hand' => $onHand,
                'coming' => $coming,
                'cover_days' => $estDaily > 0 ? (int) floor(($onHand + $coming) / $estDaily) : null,
                'goal' => $goal,
                'gap' => $gap,
                'source_on_hand' => (float) ($stock[$code][$source]['on_hand'] ?? 0),
                'source_spare' => $spare,
                'suggest' => $suggest,
                'status' => $suggest >= $gap ? 'full' : ($suggest > 0 ? 'partial' : 'none'),
                'out' => $onHand <= 0,
                'alt' => $alt,
                'price' => round($price, 2),
                'month_value' => round($estDaily * 30 * $price),
                'lost_days' => (int) round($lostDays),
                'lost_value' => (int) round($lostPcs * $price),
                'halo_value' => (int) round($lostDocs * $haloPerDoc),
                'anchor_pct' => $b && $b['docs'] > 0 ? (int) round($b['anchors'] / $b['docs'] * 100) : 0,
                'basket_docs' => $b['docs'] ?? 0,
            ];
        }

        usort($rows, fn ($a, $b) => ($b['lost_value'] + $b['halo_value']) <=> ($a['lost_value'] + $a['halo_value']));

        return $this->result($p, $rows, $onlineUntil);
    }

    /**
     * Per item, over showroom register invoices: how many invoices carry it,
     * its pieces, in how many it is the biggest line (the «anchor» — the visit
     * was likely for it), and the value of the OTHER lines on those anchor
     * invoices. Credit memos are left out: this describes baskets, not totals.
     *
     * @return array<string, array{docs: int, qty: float, anchors: int, halo: float}>
     */
    private function basketStats(Carbon $from, Carbon $to): array
    {
        $items = DB::table('sap_invoice_lines as l')
            ->join('sap_invoices as i', 'i.id', '=', 'l.sap_invoice_id')
            ->where('i.card_code', self::RETAIL_CARD)
            ->where('i.cancelled', 'N')
            ->whereBetween('i.doc_date', [$from->toDateString(), $to->toDateString()])
            ->whereNotNull('l.warehouse_code')
            ->whereNotIn('l.warehouse_code', self::ONLINE_WAREHOUSES)
            ->groupBy('l.sap_invoice_id', 'l.item_code')
            ->select('l.sap_invoice_id as doc', 'l.item_code', DB::raw('SUM(l.quantity) as q'), DB::raw('SUM(COALESCE(l.line_revenue, 0)) as rev'));

        $docs = DB::query()->fromSub($items, 'x')
            ->groupBy('x.doc')
            ->select('x.doc', DB::raw('SUM(x.rev) as tot'), DB::raw('MAX(x.rev) as mx'));

        return DB::query()->fromSub($items, 'a')
            ->joinSub($docs, 'd', 'd.doc', '=', 'a.doc')
            ->groupBy('a.item_code')
            ->select(
                'a.item_code',
                DB::raw('COUNT(*) as docs'),
                DB::raw('SUM(a.q) as qty'),
                DB::raw('SUM(CASE WHEN a.rev > 0 AND a.rev >= d.mx THEN 1 ELSE 0 END) as anchors'),
                DB::raw('SUM(CASE WHEN a.rev > 0 AND a.rev >= d.mx THEN d.tot - a.rev ELSE 0 END) as halo'),
            )
            ->get()
            ->mapWithKeys(fn ($r) => [$r->item_code => [
                'docs' => (int) $r->docs, 'qty' => (float) $r->qty, 'anchors' => (int) $r->anchors, 'halo' => max(0.0, (float) $r->halo),
            ]])
            ->all();
    }

    /**
     * What a warehouse can give without running itself short: its free stock
     * less [keep] days of its own sales (ShipGo: its online orders), and a
     * showroom or ShipGo keeps a shelf minimum too.
     */
    private function spare(float $available, float $ownQty, string $wh, array $p): int
    {
        $daily = max(0, $ownQty) / $p['window'];
        $reserve = ceil($daily * $p['keep']);
        if (! in_array($wh, BranchInsightsService::CENTRAL_WAREHOUSES, true)) {
            $reserve = max($reserve, self::MIN_SHELF);
        }

        return (int) max(0, floor($available - $reserve));
    }

    /**
     * Net pieces and ex-VAT revenue per item × line warehouse: invoices less
     * credit memos, cancelled documents ignored.
     *
     * @return array<string, array<string, array{qty: float, rev: float}>>
     */
    private function netByItemWarehouse(callable $scope, Carbon $from, Carbon $to): array
    {
        $out = [];
        $pull = function (string $head, string $lines, string $fk, int $sign) use ($scope, $from, $to, &$out) {
            $q = DB::table("$lines as l")
                ->join("$head as h", 'h.id', '=', "l.$fk")
                ->where('h.cancelled', 'N')
                ->whereBetween('h.doc_date', [$from->toDateString(), $to->toDateString()])
                ->whereNotNull('l.warehouse_code')
                ->groupBy('l.item_code', 'l.warehouse_code')
                ->select('l.item_code', 'l.warehouse_code', DB::raw('SUM(l.quantity) as qty'), DB::raw('SUM(COALESCE(l.line_revenue, 0)) as rev'));
            $scope($q, 'h');
            foreach ($q->get() as $r) {
                $cell = &$out[$r->item_code][$r->warehouse_code];
                $cell['qty'] = ($cell['qty'] ?? 0) + $sign * (float) $r->qty;
                $cell['rev'] = ($cell['rev'] ?? 0) + $sign * (float) $r->rev;
                unset($cell);
            }
        };
        $pull('sap_invoices', 'sap_invoice_lines', 'sap_invoice_id', 1);
        $pull('sap_credit_memos', 'sap_credit_memo_lines', 'sap_credit_memo_id', -1);

        return $out;
    }

    /**
     * item_code => pieces still to arrive at $target: open SAP transfer requests
     * in the mirror, plus requests this page posted that the transfer sync has
     * not mirrored yet.
     */
    public function openRequestsTo(string $target): array
    {
        $open = DB::table('sap_stock_transfer_lines as l')
            ->join('sap_stock_transfers as t', 't.id', '=', 'l.stock_transfer_id')
            ->where('t.sap_database', 'PPTC_V5_PROD')
            ->where('t.to_warehouse', $target)
            ->where('t.document_status', 'bost_Open')
            ->where(fn ($q) => $q->whereNull('l.line_status')->orWhere('l.line_status', '<>', 'bost_Close'))
            ->groupBy('l.item_code')
            ->select('l.item_code', DB::raw('SUM(l.quantity - COALESCE(l.received_quantity, 0)) as v'))
            ->pluck('v', 'item_code')
            ->map(fn ($v) => max(0.0, (float) $v))
            ->all();

        $mirrored = DB::table('sap_stock_transfers')->where('sap_database', 'PPTC_V5_PROD')->where('to_warehouse', $target)
            ->where('creation_date', '>=', now()->subDays(7)->startOfDay())->pluck('doc_entry')->map(fn ($v) => (int) $v)->all();
        BranchGapTransferRequest::query()
            ->where('to_warehouse', $target)
            ->where('status', BranchGapTransferRequest::STATUS_POSTED)
            ->where('created_at', '>=', now()->subDays(3))
            ->get()
            ->reject(fn ($r) => in_array((int) $r->doc_entry, $mirrored, true))
            ->each(function ($r) use (&$open) {
                foreach ((array) $r->lines as $line) {
                    $open[$line['item_code']] = ($open[$line['item_code']] ?? 0) + (float) $line['quantity'];
                }
            });

        return $open;
    }

    private function productMeta(array $codes): array
    {
        $out = [];
        foreach (array_chunk($codes, 800) as $chunk) {
            // A code can exist per source; the production row is read last and wins.
            DB::table('products')->whereIn('item_code', $chunk)->orderByDesc('source')
                ->get(['item_code', 'zb_name_ar', 'item_name', 'piece_barcode', 'zb_categories_ar'])
                ->each(function ($r) use (&$out) {
                    $out[$r->item_code] = [
                        'name' => $r->zb_name_ar ?: ($r->item_name ?: $r->item_code),
                        'barcode' => $r->piece_barcode ?: null,
                    ] + self::categories((string) $r->zb_categories_ar);
                });
        }

        return $out;
    }

    /**
     * The store's category paths («قطط > طعام > الطعام الرطب», «العلامات
     * التجارية > كت كات»…) as the pets, «pet › department»s and brand.
     *
     * @return array{pets: array<int,string>, depts: array<int,string>, brand: ?string}
     */
    public static function categories(string $raw): array
    {
        $pets = $depts = [];
        $brand = null;
        foreach (array_filter(array_map('trim', explode(',', $raw))) as $path) {
            $parts = array_map('trim', explode('>', $path));
            if ($parts[0] === 'العلامات التجارية') {
                $brand ??= $parts[1] ?? null;
            } elseif ($parts[0] !== 'المعايير الصحية') {
                $pets[$parts[0]] = true;
                if (isset($parts[1])) {
                    $depts[$parts[0] . ' › ' . $parts[1]] = true;
                }
            }
        }

        return ['pets' => array_keys($pets), 'depts' => array_keys($depts), 'brand' => $brand];
    }

    /** KPI totals of a set of rows (the page recounts them for its filtered set). */
    public static function totals(array $rows): array
    {
        $c = collect($rows);

        return [
            'items' => $c->count(),
            'out' => $c->where('out', true)->count(),
            'transferable' => $c->where('suggest', '>', 0)->count(),
            'transfer_pcs' => (int) $c->sum('suggest'),
            'gap_pcs' => (int) $c->sum('gap'),
            'no_source' => $c->where('status', 'none')->count(),
            'month_value' => (int) $c->sum('month_value'),
            'lost_value' => (int) $c->sum('lost_value'),
            'halo_value' => (int) $c->sum('halo_value'),
        ];
    }

    private function result(array $p, array $rows, ?string $onlineUntil): array
    {
        return [
            'params' => $p,
            'rows' => $rows,
            'online_until' => $onlineUntil ? Carbon::parse($onlineUntil)->toDateString() : null,
            'generated_at' => now()->toIso8601String(),
            'totals' => self::totals($rows),
        ];
    }
}
