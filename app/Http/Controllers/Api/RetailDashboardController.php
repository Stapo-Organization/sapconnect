<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Branch\BranchInsightsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * RetailDashboard (لوحة البيع بالتجزئة) — the owner's cross-branch command
 * centre. Read-only; gated by `feature:retail_dashboard.view` (Super Admin).
 *
 *   GET /retail-dashboard                      → one card per exhibition
 *   GET /retail-dashboard/branches/{code}      → full drill-down for one store
 *
 * All numbers come from BranchInsightsService, which reuses the existing
 * intelligence/sales tables. Nothing is written.
 */
class RetailDashboardController extends Controller
{
    public function __construct(private BranchInsightsService $insights)
    {
    }

    public function index(Request $request): JsonResponse
    {
        [$start, $end, $period] = $this->insights->resolvePeriod(
            $request->query('period'),
            $request->query('from'),
            $request->query('to'),
        );

        $exhibitions = $this->insights->exhibitions();
        $revenue = $this->insights->revenueByWarehouse($start, $end);
        $actual = $this->insights->actualProfitByWarehouse($start, $end);
        // The blended margin is only a fallback for warehouses that have no SAP
        // actual-profit rows in the period. Computing it is the heaviest query in
        // this endpoint, so skip it entirely when every branch already has actuals
        // (the usual case for recent periods) and only pay for it when needed.
        $needsBlend = collect($exhibitions)->keys()->contains(fn ($code) => ! isset($actual[$code]));
        $margins = $needsBlend ? $this->insights->blendedMarginByWarehouse($start, $end) : [];

        $cards = [];
        $totals = ['net' => 0.0, 'gross' => 0.0, 'returns' => 0.0, 'invoices' => 0, 'profit' => 0.0];

        foreach ($exhibitions as $code => $wh) {
            $rev = $revenue[$code] ?? $this->insights->emptyRevenue();
            $pulse = $this->insights->pulseRow($code);
            $ops = $this->insights->opsCounts($code);
            // Prefer SAP's actual gross profit; fall back to the blended estimate.
            $profit = $actual[$code] ?? $this->insights->profitBlock($rev['net'], $margins[$code] ?? null);

            $totals['net'] += $rev['net'];
            $totals['gross'] += $rev['gross'];
            $totals['returns'] += $rev['returns'];
            $totals['invoices'] += $rev['invoices'];
            $totals['profit'] += $profit['profit'];

            $cards[] = [
                'warehouse' => ['code' => $code, 'name' => $wh->warehouse_name],
                'revenue' => $rev,
                'profit' => $profit,
                'score' => $pulse ? round((float) $pulse->score, 1) : null,
                'rank' => $pulse && $pulse->rank !== null ? (int) $pulse->rank : null,
                'total_branches' => $pulse && $pulse->total_branches !== null ? (int) $pulse->total_branches : null,
                'bleeding_monthly_sar' => $pulse ? round((float) $pulse->bleeding_monthly_sar, 2) : 0.0,
                'trapped_capital_sar' => $pulse ? round((float) $pulse->trapped_capital_sar, 2) : 0.0,
                'ops' => $ops,
                'ops_total' => $ops['quality_pending'] + $ops['counting_active'] + $ops['transfers_new'] + $ops['zooboxi_pending'],
            ];
        }

        $cards = $this->sortCards($cards, $request->query('sort', 'revenue'));

        $trend = $this->insights->salesProfitTrend($start, $end, $period === 'today' ? 'hour' : ($period === 'year' ? 'month' : 'day'));

        return response()->json([
            'generated_at' => now()->toIso8601String(),
            'period' => ['key' => $period, 'from' => $start->toDateString(), 'to' => $end->toDateString()],
            'trend' => $trend,
            'totals' => [
                'net' => round($totals['net'], 2),
                'gross' => round($totals['gross'], 2),
                'returns' => round($totals['returns'], 2),
                'invoices' => $totals['invoices'],
                'profit' => round($totals['profit'], 2),
                'branches' => count($cards),
            ],
            'branches' => $cards,
        ]);
    }

    public function branch(Request $request, string $warehouseCode): JsonResponse
    {
        $exhibitions = $this->insights->exhibitions();
        $wh = $exhibitions->get($warehouseCode);
        if (!$wh) {
            return response()->json(['message' => 'المعرض غير موجود'], 404);
        }

        [$start, $end, $period] = $this->insights->resolvePeriod(
            $request->query('period'),
            $request->query('from'),
            $request->query('to'),
        );

        $revenue = $this->insights->revenueByWarehouse($start, $end);
        $rev = $revenue[$warehouseCode] ?? $this->insights->emptyRevenue();
        $aov = $rev['invoices'] > 0 ? round($rev['net'] / $rev['invoices'], 2) : 0.0;

        $actual = $this->insights->actualProfitByWarehouse($start, $end);
        $margins = $this->insights->blendedMarginByWarehouse($start, $end);
        $profit = $actual[$warehouseCode] ?? $this->insights->profitBlock($rev['net'], $margins[$warehouseCode] ?? null);

        $pulse = $this->insights->pulseRow($warehouseCode);

        return response()->json([
            'generated_at' => now()->toIso8601String(),
            'period' => ['key' => $period, 'from' => $start->toDateString(), 'to' => $end->toDateString()],
            'warehouse' => ['code' => $warehouseCode, 'name' => $wh->warehouse_name],
            'revenue' => array_merge($rev, ['aov' => $aov]),
            'profit' => $profit,
            'trend' => $this->insights->salesProfitTrend($start, $end, $period === 'today' ? 'hour' : ($period === 'year' ? 'month' : 'day'), $warehouseCode),
            'top_products' => $this->insights->topProducts($warehouseCode, $start, $end, 10),
            'score' => $this->insights->scoreBlock($pulse),
            'vitals' => $this->insights->vitalsBlock($pulse),
            'levers' => [
                'bleeding' => [
                    'total_monthly_sar' => $pulse ? round((float) $pulse->bleeding_monthly_sar, 2) : 0.0,
                    'items' => $this->insights->bleedingItems($warehouseCode, 6),
                ],
                'trapped' => [
                    'total_sar' => $pulse ? round((float) $pulse->trapped_capital_sar, 2) : 0.0,
                    'items' => $this->insights->trappedItems($warehouseCode, 6),
                ],
            ],
            'ops' => $this->insights->opsCounts($warehouseCode),
        ]);
    }

    /**
     * Full list for one branch section — powers the "More" full pages behind the
     * compact cards on the branch detail screen.
     *   type=bleeding|trapped  → snapshot money-lever items (period-independent)
     *   type=top               → best-sellers for the selected period
     */
    public function branchItems(Request $request, string $warehouseCode): JsonResponse
    {
        $exhibitions = $this->insights->exhibitions();
        $wh = $exhibitions->get($warehouseCode);
        if (!$wh) {
            return response()->json(['message' => 'المعرض غير موجود'], 404);
        }

        $type = $request->query('type', 'bleeding');
        $limit = min((int) $request->query('limit', 60), 100);

        $items = match ($type) {
            'trapped' => $this->insights->trappedItems($warehouseCode, $limit),
            'top' => (function () use ($request, $warehouseCode, $limit) {
                [$start, $end] = $this->insights->resolvePeriod(
                    $request->query('period'),
                    $request->query('from'),
                    $request->query('to'),
                );
                return $this->insights->topProducts($warehouseCode, $start, $end, $limit);
            })(),
            default => $this->insights->bleedingItems($warehouseCode, $limit),
        };

        return response()->json([
            'warehouse' => ['code' => $warehouseCode, 'name' => $wh->warehouse_name],
            'type' => $type,
            'count' => count($items),
            'items' => $items,
        ]);
    }

    private function sortCards(array $cards, ?string $sort): array
    {
        $key = match ($sort) {
            'score' => fn ($c) => $c['score'] ?? -1,
            'bleeding' => fn ($c) => $c['bleeding_monthly_sar'],
            'profit' => fn ($c) => $c['profit']['profit'] ?? 0,
            'revenue' => fn ($c) => $c['revenue']['net'],
            default => fn ($c) => $c['revenue']['net'],
        };
        usort($cards, fn ($a, $b) => $key($b) <=> $key($a));
        return $cards;
    }
}
