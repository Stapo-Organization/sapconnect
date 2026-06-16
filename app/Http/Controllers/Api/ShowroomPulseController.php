<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BranchActionRequest;
use App\Models\Warehouse;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * نبض المعرض (Showroom Pulse) — the per-branch decision dashboard.
 *
 * Read-only intelligence: the branch health score + four vital signs (from
 * branch_pulse_scores) and the three "money levers" — 🔴 stop the bleeding
 * (lost-sales radar), 🟡 free your cash (trapped capital) and 🟢 grow the basket
 * (frequently-bought-together) — all scoped to the manager's warehouse(s) and
 * sourced from branch_product_intelligence + product_associations. Each lever
 * item carries the product image, barcode and SAP code for the showroom floor.
 *
 * Two write actions raise SUGGESTIONS to the owner (never touch SAP / pricing):
 * requestTransfer and suggestDiscount.
 */
class ShowroomPulseController extends Controller
{
    private const LEVER_LIMIT = 8;       // shown inline on the dashboard
    private const LEVER_MAX = 200;       // ceiling for the "show all" list
    private const BASKET_LIMIT = 6;      // shown inline on the dashboard
    private const BASKET_MAX = 50;       // ceiling for the basket "show all" list
    private const MIN_NETWORK_STOCK = 100; // hide bleeding items with <100 units network-wide (not worth a transfer)

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $codes = $this->warehouseCodes($user);

        $warehouse = $this->resolveWarehouse($request, $codes);
        if ($warehouse === null) {
            return response()->json(['message' => 'لا يوجد فرع متاح'], 404);
        }
        if (!empty($codes) && !in_array($warehouse, $codes, true)) {
            return response()->json(['message' => 'غير مصرح لك بهذا الفرع'], 403);
        }

        $pulse = DB::table('branch_pulse_scores')->where('warehouse_code', $warehouse)->first();

        return response()->json([
            'generated_at' => now()->toIso8601String(),
            'warehouse' => [
                'code' => $warehouse,
                'name' => $this->warehouseName($warehouse),
            ],
            'available_warehouses' => $this->availableWarehouses($codes),
            'score' => $this->scoreBlock($pulse),
            'vitals' => $this->vitalsBlock($pulse),
            'levers' => [
                'bleeding' => [
                    'total_monthly_sar' => $pulse ? (float) $pulse->bleeding_monthly_sar : 0.0,
                    'total_count' => $this->bleedingQuery($warehouse)->count(),
                    'items' => $this->mapBleeding($this->bleedingQuery($warehouse)->limit(self::LEVER_LIMIT)->get()),
                ],
                'trapped' => [
                    'total_sar' => $pulse ? (float) $pulse->trapped_capital_sar : 0.0,
                    'total_count' => $this->trappedQuery($warehouse)->count(),
                    'items' => $this->mapTrapped($this->trappedQuery($warehouse)->limit(self::LEVER_LIMIT)->get(), $warehouse),
                ],
                'basket' => $this->basketBlock($warehouse),
            ],
        ]);
    }

    /**
     * GET /showroom-pulse/lever?type=bleeding|trapped — the full list behind
     * the dashboard's "إظهار الكل" button (capped at LEVER_MAX).
     */
    public function leverItems(Request $request): JsonResponse
    {
        $user = $request->user();
        $codes = $this->warehouseCodes($user);
        $warehouse = $this->resolveWarehouse($request, $codes);

        if ($warehouse === null) {
            return response()->json(['message' => 'لا يوجد فرع متاح'], 404);
        }
        if (!empty($codes) && !in_array($warehouse, $codes, true)) {
            return response()->json(['message' => 'غير مصرح لك بهذا الفرع'], 403);
        }

        $type = $request->query('type');
        if ($type === 'bleeding') {
            $items = $this->mapBleeding($this->bleedingQuery($warehouse)->limit(self::LEVER_MAX)->get());
        } elseif ($type === 'trapped') {
            $items = $this->mapTrapped($this->trappedQuery($warehouse)->limit(self::LEVER_MAX)->get(), $warehouse);
        } elseif ($type === 'basket') {
            $items = $this->basketLever($warehouse, self::BASKET_MAX);
        } else {
            return response()->json(['message' => 'نوع غير معروف'], 422);
        }

        return response()->json([
            'warehouse' => ['code' => $warehouse, 'name' => $this->warehouseName($warehouse)],
            'type' => $type,
            'items' => $items,
        ]);
    }

    /**
     * POST /showroom-pulse/transfer-request — manager asks for more stock of a
     * starved/out-of-stock item. Recorded as a suggestion for the owner.
     */
    public function requestTransfer(Request $request): JsonResponse
    {
        $data = $request->validate([
            'item_code' => 'required|string',
            'warehouse_code' => 'required|string',
            'quantity' => 'nullable|numeric|min:0',
            'note' => 'nullable|string|max:500',
        ]);

        return $this->raiseRequest($request, 'transfer', $data, 'تم رفع طلب التحويل للمالك');
    }

    /**
     * POST /showroom-pulse/discount-suggestion — manager suggests clearing a
     * trapped-capital item. Suggest-only; the owner approves any markdown.
     */
    public function suggestDiscount(Request $request): JsonResponse
    {
        $data = $request->validate([
            'item_code' => 'required|string',
            'warehouse_code' => 'required|string',
            'note' => 'nullable|string|max:500',
        ]);

        return $this->raiseRequest($request, 'discount', $data, 'تم رفع اقتراح الخصم للمالك');
    }

    // ─── Write helper ────────────────────────────────────────────

    private function raiseRequest(Request $request, string $type, array $data, string $message): JsonResponse
    {
        $user = $request->user();
        $codes = $this->warehouseCodes($user);
        if (!empty($codes) && !in_array($data['warehouse_code'], $codes, true)) {
            return response()->json(['message' => 'غير مصرح لك بهذا الفرع'], 403);
        }

        $bpi = DB::table('branch_product_intelligence')
            ->where('warehouse_code', $data['warehouse_code'])
            ->where('item_code', $data['item_code'])
            ->first();

        $req = BranchActionRequest::updateOrCreate(
            [
                'type' => $type,
                'item_code' => $data['item_code'],
                'warehouse_code' => $data['warehouse_code'],
                'status' => 'pending',
            ],
            [
                'requested_by' => $user->id,
                'quantity' => $data['quantity'] ?? null,
                'note' => $data['note'] ?? null,
                'meta' => $bpi ? [
                    'health_status' => $bpi->health_status,
                    'current_stock' => (float) $bpi->current_stock,
                    'velocity_blended' => (float) $bpi->velocity_blended,
                    'lost_sales_monthly' => (float) $bpi->lost_sales_monthly,
                    'capital_at_risk_sar' => (float) $bpi->capital_at_risk_sar,
                ] : null,
            ]
        );

        $this->notifyOwner($type, $data['warehouse_code'], $data['item_code']);

        return response()->json(['success' => true, 'request_id' => $req->id, 'message' => $message]);
    }

    private function notifyOwner(string $type, string $warehouse, string $itemCode): void
    {
        try {
            Log::info('Showroom Pulse request raised', [
                'type' => $type,
                'warehouse' => $warehouse,
                'item_code' => $itemCode,
            ]);
        } catch (\Throwable $e) {
            // never block the request on notification
        }
    }

    // ─── Read blocks ─────────────────────────────────────────────

    private function scoreBlock(?object $pulse): ?array
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

    private function vitalsBlock(?object $pulse): array
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

    // 🔴 أوقف النزيف — fast movers out of / about to run out of stock, by lost revenue.
    private function bleedingQuery(string $warehouse)
    {
        return DB::table('branch_product_intelligence')
            ->where('warehouse_code', $warehouse)
            ->whereIn('health_status', ['starved', 'stockout', 'low'])
            // Only worth surfacing if a meaningful transfer is possible — i.e. the
            // network still holds >= MIN_NETWORK_STOCK units of the item.
            ->whereRaw(
                '(SELECT COALESCE(SUM(w.in_stock), 0) FROM warehouse_item_stocks w WHERE w.item_code = branch_product_intelligence.item_code) >= ?',
                [self::MIN_NETWORK_STOCK]
            )
            ->orderByDesc(DB::raw('lost_sales_monthly * COALESCE(unit_retail_sar, unit_cost_sar / 0.6, 0)'))
            ->orderBy('days_of_cover');
    }

    private function mapBleeding($rows): array
    {
        $codes = $rows->pluck('item_code')->all();
        $meta = $this->productMeta($codes);
        // Network-wide stock (all warehouses) — tells the manager a transfer is feasible
        // even when this branch is at zero.
        $totalStock = $this->totalStock($codes);

        return $rows->map(function ($r) use ($meta, $totalStock) {
            $m = $meta[$r->item_code] ?? null;
            $unitRevenue = $r->unit_retail_sar !== null
                ? (float) $r->unit_retail_sar
                : ($r->unit_cost_sar !== null ? (float) $r->unit_cost_sar / 0.6 : 0.0);
            return [
                'item_code' => $r->item_code,
                'name' => $m['name'] ?? $r->item_code,
                'barcode' => $m['barcode'] ?? null,
                'image_url' => $m['image_url'] ?? $this->imageUrl($r->item_code),
                'health_status' => $r->health_status,
                'current_stock' => (float) $r->current_stock,
                'total_stock' => (float) ($totalStock[$r->item_code] ?? 0),
                'velocity_blended' => (float) $r->velocity_blended,
                'days_of_cover' => $r->days_of_cover !== null ? (float) $r->days_of_cover : null,
                'lost_sales_monthly' => (float) $r->lost_sales_monthly,
                'lost_revenue_monthly' => round((float) $r->lost_sales_monthly * $unitRevenue, 2),
            ];
        })->values()->all();
    }

    /** item_code => SUM(in_stock) across ALL warehouses (network-wide on-hand). */
    private function totalStock(array $codes): array
    {
        if (empty($codes)) {
            return [];
        }
        return DB::table('warehouse_item_stocks')
            ->whereIn('item_code', $codes)
            ->selectRaw('item_code, SUM(in_stock) total')
            ->groupBy('item_code')
            ->pluck('total', 'item_code')
            ->all();
    }

    // 🟡 حرّر فلوسك — trapped capital (dead + overstock), by SAR at risk.
    private function trappedQuery(string $warehouse)
    {
        return DB::table('branch_product_intelligence')
            ->where('warehouse_code', $warehouse)
            ->whereIn('health_status', ['overstock', 'dead'])
            ->where('capital_at_risk_sar', '>', 0)
            ->orderByDesc('capital_at_risk_sar');
    }

    private function mapTrapped($rows, string $warehouse): array
    {
        $codes = $rows->pluck('item_code')->all();
        $meta = $this->productMeta($codes);
        $today = Carbon::today();
        // Denominator for "نسبة القيمة": the branch's TOTAL trapped capital, so each
        // item shows its share of the idle cash (Pareto) — not just an absolute SAR.
        $branchTrapped = (float) $this->trappedQuery($warehouse)->sum('capital_at_risk_sar');
        // Committed (reserved) per item → available = stock − committed, the basis
        // for the trapped story (committed stock isn't idle).
        $committed = DB::table('warehouse_item_stocks')
            ->where('warehouse_code', $warehouse)
            ->whereIn('item_code', $codes)
            ->pluck('committed', 'item_code');

        return $rows->map(function ($r) use ($meta, $today, $branchTrapped, $committed) {
            $m = $meta[$r->item_code] ?? null;
            $stagnation = $r->last_sale_date
                ? (int) abs($today->diffInDays(Carbon::parse($r->last_sale_date)))
                : null;
            $cap = (float) $r->capital_at_risk_sar;
            $stock = (float) $r->current_stock;
            $com = (float) ($committed[$r->item_code] ?? 0);
            return [
                'item_code' => $r->item_code,
                'name' => $m['name'] ?? $r->item_code,
                'barcode' => $m['barcode'] ?? null,
                'image_url' => $m['image_url'] ?? $this->imageUrl($r->item_code),
                'health_status' => $r->health_status,
                'current_stock' => $stock,
                'committed' => $com,
                'available' => max(0, $stock - $com),
                'velocity_blended' => (float) $r->velocity_blended,
                'demand_rate' => (float) ($r->demand_rate ?? $r->velocity_blended),
                'days_of_cover' => $r->days_of_cover !== null ? (float) $r->days_of_cover : null,
                'excess_units' => (float) $r->excess_units,
                'stagnation_days' => $stagnation,
                'capital_at_risk_sar' => $cap,
                'value_ratio_pct' => $branchTrapped > 0 ? round($cap / $branchTrapped * 100, 1) : 0.0,
            ];
        })->values()->all();
    }

    /**
     * Basket block for the dashboard: the full cross-brand list (capped at
     * BASKET_MAX) computed once, exposing both the inline slice and the true
     * total so the app can show "إظهار الكل (N)".
     */
    private function basketBlock(string $warehouse): array
    {
        $all = $this->basketLever($warehouse, self::BASKET_MAX);
        return [
            'total_count' => count($all),
            'items' => array_slice($all, 0, self::BASKET_LIMIT),
        ];
    }

    // 🟢 كبّر السلة — frequently-bought-together pairs where BOTH items are in stock here.
    private function basketLever(string $warehouse, int $limit): array
    {
        $rows = DB::table('product_associations as pa')
            ->join('warehouse_item_stocks as sa', function ($j) use ($warehouse) {
                $j->on('sa.item_code', '=', 'pa.item_code_a')
                    ->where('sa.warehouse_code', '=', $warehouse)
                    ->where('sa.in_stock', '>', 0);
            })
            ->join('warehouse_item_stocks as sb', function ($j) use ($warehouse) {
                $j->on('sb.item_code', '=', 'pa.item_code_b')
                    ->where('sb.warehouse_code', '=', $warehouse)
                    ->where('sb.in_stock', '>', 0);
            })
            ->where('pa.rule_type', 'fbt')
            ->orderByDesc('pa.score')
            // Fetch a wide candidate pool: pairs are stored in both directions and
            // many top ones are same-brand (variants bought together) — both get
            // dropped below, so we over-fetch to fill the cross-brand list.
            ->limit($limit * 8)
            ->get(['pa.item_code_a', 'pa.item_code_b', 'pa.lift', 'pa.confidence', 'pa.co_count']);

        $codes = $rows->pluck('item_code_a')->merge($rows->pluck('item_code_b'))->unique()->all();
        $meta = $this->productMeta($codes);

        $seen = [];
        $items = [];
        foreach ($rows as $r) {
            $key = $r->item_code_a < $r->item_code_b
                ? $r->item_code_a . '|' . $r->item_code_b
                : $r->item_code_b . '|' . $r->item_code_a;
            if (isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;

            // Skip same-brand pairs: same-brand products already sit together on
            // the brand's shelf, so "display them side by side" is no advice. Only
            // cross-brand pairings are actionable merchandising. (Null/unknown
            // brand on either side → keep, can't assume adjacency.)
            $ga = $meta[$r->item_code_a]['group'] ?? null;
            $gb = $meta[$r->item_code_b]['group'] ?? null;
            if ($ga !== null && $gb !== null && (string) $ga === (string) $gb) {
                continue;
            }
            $items[] = [
                'item_a' => $this->basketRef($r->item_code_a, $meta),
                'item_b' => $this->basketRef($r->item_code_b, $meta),
                'lift' => (float) $r->lift,
                'confidence' => (float) $r->confidence,
                'co_count' => (int) $r->co_count,
            ];
            if (count($items) >= $limit) {
                break;
            }
        }

        return $items;
    }

    private function basketRef(string $code, array $meta): array
    {
        $m = $meta[$code] ?? null;
        return [
            'code' => $code,
            'name' => $m['name'] ?? $code,
            'image_url' => $m['image_url'] ?? $this->imageUrl($code),
        ];
    }

    // ─── Helpers ─────────────────────────────────────────────────

    /** item_code => ['name','barcode','image_url'] (Arabic name, falling back to item_name). */
    private function productMeta(array $codes): array
    {
        if (empty($codes)) {
            return [];
        }
        return DB::table('products')
            ->whereIn('item_code', $codes)
            ->get(['item_code', 'zb_name_ar', 'item_name', 'piece_barcode', 'items_group_code'])
            ->mapWithKeys(fn ($p) => [$p->item_code => [
                'name' => $p->zb_name_ar ?: ($p->item_name ?: $p->item_code),
                'barcode' => $p->piece_barcode,
                'image_url' => $this->imageUrl($p->item_code),
                'group' => $p->items_group_code, // brand code → used to drop same-brand pairs
            ]])
            ->all();
    }

    /** Product image URL — same pattern the counting/scan screens already render. */
    private function imageUrl(string $code): string
    {
        return 'https://ppte.sa/imghd/' . substr($code, 0, 4) . '/' . $code . '.png';
    }

    private function resolveWarehouse(Request $request, array $codes): ?string
    {
        $requested = $request->query('warehouse');
        if ($requested) {
            return (string) $requested;
        }
        if (!empty($codes)) {
            return (string) $codes[0];
        }
        return DB::table('branch_pulse_scores')->orderByDesc('score')->value('warehouse_code');
    }

    private function availableWarehouses(array $codes): array
    {
        $query = Warehouse::query()->select('warehouse_code', 'warehouse_name');
        if (!empty($codes)) {
            $query->whereIn('warehouse_code', $codes);
        }
        return $query->get()
            ->map(fn ($w) => ['code' => $w->warehouse_code, 'name' => $w->warehouse_name])
            ->all();
    }

    private function warehouseName(string $code): string
    {
        return (string) (Warehouse::where('warehouse_code', $code)->value('warehouse_name') ?: $code);
    }

    /** Decode the user's warehouse codes (JSON array or scalar). Empty = admin (all branches). */
    private function warehouseCodes($user): array
    {
        if (!$user || !$user->warehouse_code) {
            return [];
        }
        $codes = $user->warehouse_code;
        if (is_string($codes)) {
            $decoded = json_decode($codes, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $codes = $decoded;
            }
        }
        return is_array($codes) ? $codes : [$codes];
    }
}
