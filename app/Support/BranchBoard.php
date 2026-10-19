<?php

namespace App\Support;

use App\Services\Branch\BranchInsightsService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Admin «الفروع» data: the branch leaderboard and one branch's full picture.
 * Every number comes from BranchInsightsService — the same source as the
 * owner app's retail dashboard — so the admin and the app always agree.
 * Results are cached for five minutes per period (the underlying scans are
 * heavy and the data only moves with the SAP sync).
 */
class BranchBoard
{
    public const PERIODS = ['today', 'week', 'month', 'year'];

    private const TTL = 300;

    public function __construct(private BranchInsightsService $insights)
    {
    }

    public static function period(?string $period): string
    {
        return in_array($period, self::PERIODS, true) ? $period : 'month';
    }

    /** @return array<string, mixed> */
    public function network(string $period): array
    {
        [$start, $end, $p] = $this->insights->resolvePeriod(self::period($period), null, null);

        return Cache::remember("branch-board:net:{$p}:{$start->toDateString()}:{$end->toDateString()}", self::TTL, function () use ($start, $end, $p) {
            $exhibitions = $this->insights->exhibitions();
            $revenue = $this->insights->revenueByWarehouse($start, $end);
            $actual = $this->insights->actualProfitByWarehouse($start, $end);
            $needsBlend = $exhibitions->keys()->contains(fn ($code) => ! isset($actual[$code]));
            $margins = $needsBlend ? $this->insights->blendedMarginByWarehouse($start, $end) : [];

            $rows = [];
            $totals = ['net' => 0.0, 'gross' => 0.0, 'returns' => 0.0, 'invoices' => 0, 'profit' => 0.0];
            foreach ($exhibitions as $code => $wh) {
                $rev = $revenue[$code] ?? $this->insights->emptyRevenue();
                $profit = $actual[$code] ?? $this->insights->profitBlock($rev['net'], $margins[$code] ?? null);
                $pulse = $this->insights->pulseRow($code);
                $ops = $this->insights->opsCounts($code);

                $totals['net'] += $rev['net'];
                $totals['gross'] += $rev['gross'];
                $totals['returns'] += $rev['returns'];
                $totals['invoices'] += $rev['invoices'];
                $totals['profit'] += $profit['profit'];

                $rows[] = [
                    'code' => $code,
                    'name' => $wh->warehouse_name,
                    'net' => $rev['net'],
                    'gross' => $rev['gross'],
                    'returns' => $rev['returns'],
                    'invoices' => $rev['invoices'],
                    'aov' => $rev['invoices'] > 0 ? round($rev['net'] / $rev['invoices'], 2) : 0.0,
                    'profit' => $profit['profit'],
                    'margin' => $profit['margin_pct'],
                    'estimated' => (bool) ($profit['estimated'] ?? false),
                    'score' => $pulse ? round((float) $pulse->score, 1) : null,
                    'rank' => $pulse && $pulse->rank !== null ? (int) $pulse->rank : null,
                    'bleeding' => $pulse ? round((float) $pulse->bleeding_monthly_sar, 2) : 0.0,
                    'trapped' => $pulse ? round((float) $pulse->trapped_capital_sar, 2) : 0.0,
                    'ops' => $ops,
                    'ops_total' => $ops['quality_pending'] + $ops['counting_active'] + $ops['transfers_new'] + $ops['zooboxi_pending'],
                ];
            }

            $max = max(array_column($rows, 'net') ?: [0]);
            foreach ($rows as &$r) {
                $r['share'] = $totals['net'] > 0 ? round($r['net'] / $totals['net'] * 100, 1) : 0.0;
                $r['bar'] = $max > 0 ? round(max(0, $r['net']) / $max * 100, 1) : 0.0;
            }
            unset($r);

            $totals['aov'] = $totals['invoices'] > 0 ? round($totals['net'] / $totals['invoices'], 2) : 0.0;
            $totals['margin'] = $totals['net'] > 0 ? round($totals['profit'] / $totals['net'] * 100, 1) : null;
            $totals['branches'] = count($rows);

            return [
                'period' => ['key' => $p, 'from' => $start->toDateString(), 'to' => $end->toDateString()],
                'totals' => $totals,
                'rows' => $rows,
                'trend' => $this->insights->salesProfitTrend($start, $end, self::granularity($p)),
            ];
        });
    }

    /** @return array<string, mixed>|null null when the code is not a selling branch */
    public function branch(string $code, string $period): ?array
    {
        $exhibitions = $this->insights->exhibitions();
        $wh = $exhibitions->get($code);
        if (! $wh) {
            return null;
        }
        [$start, $end, $p] = $this->insights->resolvePeriod(self::period($period), null, null);

        return Cache::remember("branch-board:one:{$code}:{$p}:{$start->toDateString()}:{$end->toDateString()}", self::TTL, function () use ($code, $wh, $exhibitions, $start, $end, $p) {
            $network = $this->network($p);
            $net = collect($network['rows']);
            $row = $net->firstWhere('code', $code);
            $salesRank = $net->sortByDesc('net')->values()->search(fn ($r) => $r['code'] === $code);
            $pulse = $this->insights->pulseRow($code);

            return [
                'period' => ['key' => $p, 'from' => $start->toDateString(), 'to' => $end->toDateString()],
                'code' => $code,
                'name' => $wh->warehouse_name,
                'kpi' => $row,
                'sales_rank' => $salesRank === false ? null : $salesRank + 1,
                'branch_count' => $net->count(),
                'trend' => $this->insights->salesProfitTrend($start, $end, self::granularity($p), $code),
                'top' => $this->insights->topProducts($code, $start, $end, 10),
                'score' => $this->insights->scoreBlock($pulse),
                'vitals' => $this->insights->vitalsBlock($pulse),
                'bleeding' => ['total' => $pulse ? round((float) $pulse->bleeding_monthly_sar, 2) : 0.0, 'items' => $this->insights->bleedingItems($code, 8)],
                'trapped' => ['total' => $pulse ? round((float) $pulse->trapped_capital_sar, 2) : 0.0, 'items' => $this->insights->trappedItems($code, 8)],
                'ops' => $row['ops'] ?? $this->insights->opsCounts($code),
                'stock' => $this->stock($code),
                'compare' => $this->compare($row, $network['totals']),
                'siblings' => $net->sortBy('name')->map(fn ($r) => ['code' => $r['code'], 'name' => $r['name']])->values()->all(),
            ];
        });
    }

    /**
     * The branch against the network average for the same period.
     *
     * @return array<int, array{key:string, branch:?float, network:?float, better:string}>
     */
    private function compare(?array $row, array $totals): array
    {
        if (! $row || ($totals['branches'] ?? 0) === 0) {
            return [];
        }
        $avgNet = $totals['net'] / max(1, $totals['branches']);
        $rate = fn ($a, $b) => $b > 0 ? round($a / $b * 100, 1) : null;

        return [
            ['key' => 'net', 'branch' => $row['net'], 'network' => round($avgNet, 2), 'better' => 'up'],
            ['key' => 'aov', 'branch' => $row['aov'], 'network' => $totals['aov'], 'better' => 'up'],
            ['key' => 'margin', 'branch' => $row['margin'], 'network' => $totals['margin'], 'better' => 'up'],
            ['key' => 'returns', 'branch' => $rate($row['returns'], $row['gross']), 'network' => $rate($totals['returns'], $totals['gross']), 'better' => 'down'],
        ];
    }

    /** @return array{skus:int, units:float, incoming:float, committed:float} */
    private function stock(string $code): array
    {
        try {
            $r = DB::table('warehouse_item_stocks')->where('warehouse_code', $code)
                ->selectRaw('SUM(CASE WHEN in_stock > 0 THEN 1 ELSE 0 END) skus, SUM(in_stock) units, SUM(ordered) incoming, SUM(committed) committed')
                ->first();

            return ['skus' => (int) ($r->skus ?? 0), 'units' => (float) ($r->units ?? 0), 'incoming' => (float) ($r->incoming ?? 0), 'committed' => (float) ($r->committed ?? 0)];
        } catch (Throwable) {
            return ['skus' => 0, 'units' => 0.0, 'incoming' => 0.0, 'committed' => 0.0];
        }
    }

    public static function granularity(string $period): string
    {
        return match ($period) {
            'today' => 'hour',
            'year' => 'month',
            default => 'day',
        };
    }
}
