<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\CalculateStockOpportunitiesJob;
use App\Models\SuggestedStockTransfer;
use App\Models\Warehouse;
use App\Services\Branch\BranchInsightsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

/**
 * StockDistribution (التوزيع الذكي للمخزون) — owner-facing view of the AI
 * replenishment suggestions, plus a button to re-run the engine.
 *
 *   GET  /stock-distribution          → suggestions (grouped source → target)
 *   GET  /stock-distribution/status   → { running, last_computed_at, pending_count }
 *   POST /stock-distribution/run      → dispatch CalculateStockOpportunitiesJob
 *
 * Read + re-generate only. Turning a suggestion into a real SAP stock transfer
 * stays in the Filament SuggestedStockTransferResource (bulk_approve).
 */
class StockDistributionController extends Controller
{
    /** Central warehouses always treated as sources (mirror of the job). */
    private const CENTRAL = ['AGL001', '3PL001', 'STL001', 'STL002'];

    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');

        $query = SuggestedStockTransfer::query()->where('status', $status);

        if ($wh = $request->query('warehouse')) {
            $query->where(function ($q) use ($wh) {
                $q->where('source_warehouse', $wh)->orWhere('target_warehouse', $wh);
            });
        }

        $rows = $query->orderByDesc('suggested_quantity')->limit(500)->get();

        // Product names + warehouse names resolved in bulk.
        $names = Warehouse::pluck('warehouse_name', 'warehouse_code');
        $productNames = \Illuminate\Support\Facades\DB::table('products')
            ->whereIn('item_code', $rows->pluck('item_code')->unique()->all())
            ->get(['item_code', 'zb_name_ar', 'item_name'])
            ->mapWithKeys(fn ($p) => [$p->item_code => ($p->zb_name_ar ?: ($p->item_name ?: $p->item_code))]);

        // Group source → target so the app can render one section per lane.
        $groups = [];
        foreach ($rows as $r) {
            $type = $request->query('transfer_type');
            $rowType = in_array($r->source_warehouse, self::CENTRAL, true) ? 'central' : 'cross_dock';
            if ($type && $type !== $rowType) {
                continue;
            }

            $key = $r->source_warehouse . '→' . $r->target_warehouse;
            if (!isset($groups[$key])) {
                $groups[$key] = [
                    'source' => ['code' => $r->source_warehouse, 'name' => BranchInsightsService::arName($r->source_warehouse, $names[$r->source_warehouse] ?? null)],
                    'target' => ['code' => $r->target_warehouse, 'name' => BranchInsightsService::arName($r->target_warehouse, $names[$r->target_warehouse] ?? null)],
                    'transfer_type' => $rowType,
                    'total_units' => 0,
                    'items' => [],
                ];
            }
            $groups[$key]['total_units'] += (int) $r->suggested_quantity;
            $groups[$key]['items'][] = [
                'id' => $r->id,
                'item_code' => $r->item_code,
                'name' => $productNames[$r->item_code] ?? $r->item_code,
                'image_url' => 'https://ppte.sa/imghd/' . substr($r->item_code, 0, 4) . '/' . $r->item_code . '.png',
                'suggested_quantity' => (int) $r->suggested_quantity,
                'source_ads' => (float) $r->source_ads,
                'source_stock' => (float) $r->source_stock,
                'target_ads' => (float) $r->target_ads,
                'target_stock' => (float) $r->target_stock,
            ];
        }

        return response()->json([
            'status' => $this->statusPayload(),
            'total_lanes' => count($groups),
            'groups' => array_values($groups),
        ]);
    }

    public function status(): JsonResponse
    {
        return response()->json($this->statusPayload());
    }

    public function run(): JsonResponse
    {
        if (Cache::get(CalculateStockOpportunitiesJob::RUNNING_KEY)) {
            return response()->json([
                'started' => false,
                'message' => 'المحرك قيد التشغيل بالفعل',
                'status' => $this->statusPayload(),
            ], 409);
        }

        // Flag with a safety TTL so a hard crash can't wedge the button forever;
        // the job clears it on success/failure well before this expires.
        Cache::put(CalculateStockOpportunitiesJob::RUNNING_KEY, true, now()->addHour());
        CalculateStockOpportunitiesJob::dispatch();

        return response()->json([
            'started' => true,
            'message' => 'بدأ تشغيل محرك التوصيات',
            'status' => $this->statusPayload(),
        ]);
    }

    private function statusPayload(): array
    {
        return [
            'running' => (bool) Cache::get(CalculateStockOpportunitiesJob::RUNNING_KEY, false),
            'last_computed_at' => Cache::get(CalculateStockOpportunitiesJob::LAST_RUN_KEY),
            'pending_count' => SuggestedStockTransfer::where('status', 'pending')->count(),
        ];
    }
}
