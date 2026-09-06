<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProductBundle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Store-facing bundle feed (woo token). The plugin pulls hourly:
 * approved/live definitions to materialise as WC products, plus the ids of
 * retired bundles it still has products for — then reports back what it did.
 */
class BundleFeedController extends Controller
{
    /** GET /api/woo/bundles/active */
    public function active(): JsonResponse
    {
        $active = ProductBundle::with('items')
            ->whereIn('status', [ProductBundle::STATUS_APPROVED, ProductBundle::STATUS_LIVE])
            ->orderByDesc('approved_at')
            ->get()
            ->map(fn ($b) => [
                'id' => $b->id,
                'template' => $b->template,
                'status' => $b->status,
                'name_ar' => $b->name_ar,
                'subtitle_ar' => $b->subtitle_ar,
                'free_label' => $b->free_label,
                'species' => $b->species,
                'kind' => $b->kind,
                'sum_retail' => (float) $b->sum_retail,
                'bundle_price' => (float) $b->bundle_price,
                'savings_pct' => (float) $b->savings_pct,
                'stock_class' => $b->stock_class,
                'warehouse_scope' => $b->warehouse_scope,
                'anchor_item_code' => $b->anchor_item_code,
                'wc_product_id' => $b->wc_product_id,
                'image_url' => $b->image_url,
                'items' => $b->items->map(fn ($it) => [
                    'item_code' => $it->item_code,
                    'barcode' => $it->barcode,
                    'name' => $it->item_name,
                    'qty' => $it->qty,
                    'role' => $it->role,
                    'unit_retail' => (float) $it->unit_retail,
                ])->values(),
            ]);

        // Bundles the owner pulled that the store still shows.
        $retired = ProductBundle::whereIn('status', [ProductBundle::STATUS_RETIRED, ProductBundle::STATUS_REJECTED])
            ->whereNotNull('wc_product_id')
            ->get(['id', 'wc_product_id'])
            ->map(fn ($b) => ['id' => $b->id, 'wc_product_id' => $b->wc_product_id]);

        return response()->json(['data' => $active, 'retired' => $retired]);
    }

    /** POST /api/woo/bundles/{id}/materialized — the store reports the outcome. */
    public function materialized(Request $request, int $id): JsonResponse
    {
        $bundle = ProductBundle::findOrFail($id);

        $data = $request->validate([
            'wc_product_id' => 'sometimes|nullable|integer',
            'status' => 'required|in:live,failed,retired',
            'error' => 'sometimes|nullable|string|max:500',
            'store_sum' => 'sometimes|nullable|numeric',
            'store_price' => 'sometimes|nullable|numeric',
        ]);

        if ($data['status'] === 'live') {
            // The store reprices on its own (VAT-inclusive) retail with the
            // approved percentage — keep the real numbers for the owner's app.
            $rationale = $bundle->rationale ?? [];
            if (isset($data['store_sum'])) {
                $rationale['store_sum'] = (float) $data['store_sum'];
                $rationale['store_price'] = (float) ($data['store_price'] ?? 0);
            }
            $bundle->update([
                'wc_product_id' => $data['wc_product_id'] ?? $bundle->wc_product_id,
                'status' => ProductBundle::STATUS_LIVE,
                'rationale' => $rationale,
            ]);
        } elseif ($data['status'] === 'retired') {
            $bundle->update(['wc_product_id' => null]);
        } else {
            $rationale = $bundle->rationale ?? [];
            $rationale['store_error'] = $data['error'] ?? 'materialise failed';
            $bundle->update(['rationale' => $rationale]);
        }

        return response()->json(['ok' => true]);
    }
}
