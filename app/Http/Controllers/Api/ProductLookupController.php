<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\WarehouseItemStock;
use App\Services\Branch\BranchInsightsService;
use App\Services\Intelligence\DemandReconstructionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Read-only product lookup for the Exhibition Manager app:
 *  • search()  — find products by name, SAP code, or barcode (the manager types
 *                any of the three and gets a ranked, thumbnailed result list).
 *  • detail()  — one product with its stock across every warehouse & showroom,
 *                plus retail price and brand.
 *
 * Pure reads against the imported SAP mirror — never writes to SAP.
 */
class ProductLookupController extends Controller
{
    /** Max rows returned by a search. */
    protected const SEARCH_LIMIT = 30;

    public function search(Request $request)
    {
        $q = trim((string) $request->query('q', ''));
        if (mb_strlen($q) < 2) {
            return response()->json(['query' => $q, 'items' => []]);
        }

        // Escape LIKE wildcards in the user's term so they search literally.
        $esc = str_replace(['%', '_'], ['\%', '\_'], $q);
        $like = '%' . $esc . '%';
        $prefix = $esc . '%';

        $products = Product::query()
            ->where('source', 'production')
            ->where(function ($w) use ($q, $like, $prefix) {
                $w->where('item_code', $q)
                    ->orWhere('piece_barcode', $q)
                    ->orWhere('item_code', 'like', $prefix)
                    ->orWhere('piece_barcode', 'like', $prefix)
                    ->orWhere('item_name', 'like', $like)
                    ->orWhere('foreign_name', 'like', $like)
                    ->orWhere('zb_name_ar', 'like', $like)
                    ->orWhere('zb_name_en', 'like', $like);
            })
            // Exact code / barcode hits float to the top, then alphabetical.
            ->orderByRaw('CASE WHEN item_code = ? OR piece_barcode = ? THEN 0 ELSE 1 END', [$q, $q])
            ->orderBy('foreign_name')
            ->limit(self::SEARCH_LIMIT)
            ->get();

        if ($products->isEmpty()) {
            return response()->json(['query' => $q, 'items' => []]);
        }

        // Network-wide stock for every matched item in a single grouped query.
        $codes = $products->pluck('item_code')->all();
        $stock = WarehouseItemStock::whereIn('item_code', $codes)
            ->select('item_code', DB::raw('SUM(in_stock) as total_stock'))
            ->groupBy('item_code')
            ->pluck('total_stock', 'item_code');

        $items = $products->map(fn (Product $p) => [
            'item_code'   => $p->item_code,
            'name'        => $this->displayName($p),
            'name_en'     => $p->item_name ?: $p->zb_name_en,
            'barcode'     => $p->piece_barcode,
            'image_url'   => $this->imageUrl($p->item_code),
            'total_stock' => (float) ($stock[$p->item_code] ?? 0),
        ])->values();

        return response()->json(['query' => $q, 'items' => $items]);
    }

    public function detail(Request $request, string $itemCode)
    {
        $product = Product::where('source', 'production')
            ->where('item_code', $itemCode)
            ->first();

        if (!$product) {
            return response()->json(['message' => 'لم يتم العثور على المنتج'], 404);
        }

        // Stock per warehouse, joined to the warehouse name, richest first.
        $rows = WarehouseItemStock::query()
            ->leftJoin('warehouses', function ($j) {
                $j->on('warehouses.warehouse_code', '=', 'warehouse_item_stocks.warehouse_code')
                    ->where('warehouses.source', '=', 'production');
            })
            ->where('warehouse_item_stocks.item_code', $itemCode)
            ->select(
                'warehouse_item_stocks.warehouse_code',
                'warehouses.warehouse_name',
                'warehouse_item_stocks.in_stock',
                'warehouse_item_stocks.committed',
                'warehouse_item_stocks.ordered'
            )
            ->orderByDesc('warehouse_item_stocks.in_stock')
            ->orderBy('warehouse_item_stocks.warehouse_code')
            ->get();

        $warehouses = $rows->map(fn ($r) => [
            'warehouse_code' => $r->warehouse_code,
            'warehouse_name' => $r->warehouse_name ?: $r->warehouse_code,
            'in_stock'       => (float) $r->in_stock,
            'committed'      => (float) $r->committed,
            'ordered'        => (float) $r->ordered,
        ])->values();

        // Guarantee the caller's own branches always appear (as 0 if the item
        // isn't stocked there), so the app's "معارضي" filter gives a definite
        // "فرعك: 0" instead of a vague "not available" — the manager's most
        // common question is "do I have this, and how much?".
        $branches = array_values(array_filter(array_map(
            'trim',
            explode(',', (string) $request->query('branches', ''))
        )));
        if (!empty($branches)) {
            $present = $warehouses->pluck('warehouse_code')->all();
            $missing = array_values(array_diff($branches, $present));
            if (!empty($missing)) {
                $names = DB::table('warehouses')
                    ->whereIn('warehouse_code', $missing)
                    ->where('source', 'production')
                    ->pluck('warehouse_name', 'warehouse_code');
                foreach ($missing as $mc) {
                    $warehouses->push([
                        'warehouse_code' => $mc,
                        'warehouse_name' => $names[$mc] ?? $mc,
                        'in_stock'       => 0.0,
                        'committed'      => 0.0,
                        'ordered'        => 0.0,
                    ]);
                }
            }
        }

        // retailPrice() expects the raw SAP prices JSON (the model casts it to
        // an array), so hand it the original stored string.
        $retail = app(DemandReconstructionService::class)
            ->retailPrice($product->getRawOriginal('prices'));

        // When the caller came from a specific branch (the bleeding "transfer"
        // item), suggest where to pull this item from and how much.
        $target = $branches[0] ?? null;
        $transferSuggestions = $target ? $this->transferSuggestions($itemCode, $target, $warehouses) : [];

        return response()->json([
            'item_code'       => $product->item_code,
            'name'            => $this->displayName($product),
            'name_en'         => $product->item_name ?: $product->zb_name_en,
            'barcode'         => $product->piece_barcode,
            'image_url'       => $this->imageUrl($product->item_code),
            'uom'             => $product->inventory_uom,
            'brand'           => optional($product->brand)->name,
            'retail_price'    => $retail,
            'total_stock'     => (float) $rows->sum('in_stock'),
            'total_committed' => (float) $rows->sum('committed'),
            'total_ordered'   => (float) $rows->sum('ordered'),
            'warehouse_count' => $rows->where('in_stock', '>', 0)->count(),
            'warehouses'      => $warehouses,
            'transfer_suggestions' => $transferSuggestions,
        ]);
    }

    /**
     * "Smart transfer" for a stocked-out branch: where to pull this item from and
     * how much. Prefers the replenishment engine's own pending suggestion; when it
     * has none (the engine only targets high-velocity thirst) it falls back to a
     * live availability plan — central warehouses first, then any surplus branch —
     * sized to roughly 30 days of the target's demand.
     *
     * @param  \Illuminate\Support\Collection  $warehouses  per-warehouse stock lines
     * @return array<int, array<string, mixed>>
     */
    private function transferSuggestions(string $itemCode, string $target, $warehouses): array
    {
        $svc = app(BranchInsightsService::class);
        $central = BranchInsightsService::CENTRAL_WAREHOUSES;
        $showrooms = array_values(array_diff($svc->retailNetworkCodes(), $central));
        $nameMap = $warehouses->pluck('warehouse_name', 'warehouse_code')->all();

        // Surplus the retail network can actually spare (mirrors the classifier):
        //  • central warehouses → all net available (they exist to distribute)
        //  • other showrooms → only their EXCESS — never stock they still need
        // so a suggested transfer never creates a new stockout at the source.
        $centralCands = $warehouses
            ->filter(fn ($w) => in_array($w['warehouse_code'], $central, true))
            ->map(fn ($w) => [
                'code' => $w['warehouse_code'],
                'name' => BranchInsightsService::arName($w['warehouse_code'], $w['warehouse_name']),
                'avail' => max(0.0, (float) $w['in_stock'] - (float) $w['committed']),
            ])
            ->filter(fn ($w) => $w['avail'] > 0)
            ->sortByDesc('avail')
            ->values();

        $showroomCands = collect();
        if (!empty($showrooms)) {
            $showroomCands = DB::table('branch_product_intelligence')
                ->where('item_code', $itemCode)
                ->whereIn('warehouse_code', $showrooms)
                ->where('warehouse_code', '!=', $target)
                ->where('excess_units', '>', 0)
                ->orderByDesc('excess_units')
                ->get(['warehouse_code', 'excess_units'])
                ->map(fn ($r) => [
                    'code' => $r->warehouse_code,
                    'name' => BranchInsightsService::arName($r->warehouse_code, $nameMap[$r->warehouse_code] ?? null),
                    'avail' => (float) $r->excess_units,
                ]);
        }

        // Central first, then the most-overstocked showrooms.
        $cands = $centralCands->concat($showroomCands)->values();

        // Gate identical to the classifier: no meaningful surplus anywhere → the real
        // remedy is a supplier order (OOS), so offer no transfer plan.
        if ($cands->sum('avail') < BranchInsightsService::OOS_NET_AVAILABLE_THRESHOLD) {
            return [];
        }

        // Size the plan to the target's ~30-day need (net of what it has / expects).
        $ti = DB::table('branch_product_intelligence')
            ->where('item_code', $itemCode)->where('warehouse_code', $target)->first();
        $ads = $ti ? (float) ($ti->ads_30 ?: $ti->velocity_blended) : 0.0;
        $monthlyNeed = max($ads * 30, $ti ? (float) $ti->lost_sales_monthly : 0.0);
        $tgt = $warehouses->firstWhere('warehouse_code', $target);
        $tgtEffective = $tgt ? ((float) $tgt['in_stock'] + (float) $tgt['ordered']) : 0.0;
        $tgtName = BranchInsightsService::arName($target, $tgt['warehouse_name'] ?? $target);
        $need = (int) ceil($monthlyNeed - $tgtEffective);
        if ($need <= 0) {
            return [];
        }

        $out = [];
        $remaining = $need;
        foreach ($cands->take(3) as $w) {
            if ($remaining <= 0) {
                break;
            }
            $qty = (int) min($remaining, $w['avail']);
            if ($qty <= 0) {
                continue;
            }
            $out[] = [
                'source' => ['code' => $w['code'], 'name' => $w['name']],
                'target' => ['code' => $target, 'name' => $tgtName],
                'quantity' => (float) $qty,
                'source_available' => (float) $w['avail'],
                'target_ads' => $ads > 0 ? round($ads, 2) : null,
                'basis' => 'availability',
            ];
            $remaining -= $qty;
        }
        return $out;
    }

    // ─── Helpers ────────────────────────────────────────────────

    /** Arabic-first display name: SAP Arabic → ZID Arabic → SAP English → code. */
    protected function displayName(Product $p): string
    {
        return $p->foreign_name ?: ($p->zb_name_ar ?: ($p->item_name ?: $p->item_code));
    }

    protected function imageUrl(string $code): string
    {
        return 'https://ppte.sa/imghd/' . substr($code, 0, 4) . '/' . $code . '.png';
    }
}
