<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ProductBundle;
use App\Services\Marketing\BundleGenerator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Owner-facing «حزم زوبوكسي» review/approval API for the Flutter app.
 * Owner-only (Super Admin). Approval re-validates channel safety
 * authoritatively — an edited price is re-checked against the cost floor
 * and the savings cap before anything can reach the store.
 */
class BundleController extends Controller
{
    private function authorizeOwner(Request $request): void
    {
        abort_unless($request->user() && $request->user()->hasRole('Super Admin'), 403, 'مخصّص للمالك فقط.');
    }

    /** GET /api/bundles/summary — badge counts for the promotions area. */
    public function summary(Request $request): JsonResponse
    {
        $this->authorizeOwner($request);

        return response()->json([
            'pending_count' => ProductBundle::where('status', ProductBundle::STATUS_SUGGESTED)->count(),
            'live_count' => ProductBundle::whereIn('status', [ProductBundle::STATUS_APPROVED, ProductBundle::STATUS_LIVE])->count(),
        ]);
    }

    /** GET /api/bundles?status= — suggested by default, round-robined by template. */
    public function index(Request $request): JsonResponse
    {
        $this->authorizeOwner($request);

        $status = $request->get('status', ProductBundle::STATUS_SUGGESTED);
        $query = ProductBundle::with('items');

        if ($status === 'history') {
            $query->whereIn('status', [ProductBundle::STATUS_RETIRED, ProductBundle::STATUS_REJECTED])
                ->orderByDesc('updated_at');
        } elseif ($status === 'live') {
            $query->whereIn('status', [ProductBundle::STATUS_APPROVED, ProductBundle::STATUS_LIVE])
                ->orderByDesc('approved_at');
        } else {
            $query->where('status', ProductBundle::STATUS_SUGGESTED);
        }

        $bundles = $query->limit(200)->get();

        // Scores are only comparable within a template (same lesson as the
        // campaign feed) — round-robin templates strongest-first for suggested.
        if ($status === ProductBundle::STATUS_SUGGESTED) {
            $groups = $bundles->sortByDesc('score')->groupBy('template')->map->values();
            $ordered = collect();
            for ($i = 0; $ordered->count() < $bundles->count(); $i++) {
                foreach ($groups as $g) {
                    if (isset($g[$i])) {
                        $ordered->push($g[$i]);
                    }
                }
            }
            $bundles = $ordered;
        }

        return response()->json(['bundles' => $bundles->map(fn ($b) => $this->row($b))->values()]);
    }

    /** GET /api/bundles/{id} */
    public function show(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);

        return response()->json(['bundle' => $this->row(ProductBundle::with('items')->findOrFail($id))]);
    }

    /**
     * POST /api/bundles/{id}/approve — optional edits: name_ar, bundle_price.
     * Re-guards the final price; the store's hourly pull then materialises it.
     */
    public function approve(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $bundle = ProductBundle::with('items')->findOrFail($id);

        abort_unless($bundle->status === ProductBundle::STATUS_SUGGESTED, 422, 'هذه الحزمة ليست بانتظار الموافقة.');

        $data = $request->validate([
            'name_ar' => 'sometimes|string|max:250',
            'subtitle_ar' => 'sometimes|nullable|string|max:250',
            'bundle_price' => 'sometimes|numeric|min:1',
        ]);

        $price = (float) ($data['bundle_price'] ?? $bundle->bundle_price);
        $cap = $bundle->template === 'smart_gift' ? BundleGenerator::CAP_GIFT : BundleGenerator::CAP_HEALTHY;
        $savings = $bundle->sum_retail > 0 ? (1 - $price / $bundle->sum_retail) * 100 : 0;

        abort_if($price < $bundle->floor_price - 0.001, 422,
            sprintf('السعر %.2f تحت الحد الأرضي %.2f — مرفوض لحماية الهامش.', $price, $bundle->floor_price));
        abort_if($savings > $cap + 0.01, 422,
            sprintf('التوفير %.0f%% يتجاوز السقف %.0f%% لهذا النوع.', $savings, $cap));

        $bundle->update([
            'name_ar' => $data['name_ar'] ?? $bundle->name_ar,
            'subtitle_ar' => array_key_exists('subtitle_ar', $data) ? $data['subtitle_ar'] : $bundle->subtitle_ar,
            'bundle_price' => round($price, 4),
            'savings_pct' => round(max($savings, 0), 2),
            'status' => ProductBundle::STATUS_APPROVED,
            'approved_by' => $request->user()->id,
            'approved_at' => now(),
        ]);

        return response()->json(['bundle' => $this->row($bundle->fresh('items'))]);
    }

    /** POST /api/bundles/{id}/reject */
    public function reject(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $bundle = ProductBundle::findOrFail($id);

        abort_unless($bundle->status === ProductBundle::STATUS_SUGGESTED, 422, 'هذه الحزمة ليست بانتظار الموافقة.');

        $bundle->update([
            'status' => ProductBundle::STATUS_REJECTED,
            'rejected_reason' => $request->input('reason'),
        ]);

        return response()->json(['ok' => true]);
    }

    /** POST /api/bundles/{id}/retire — pull a live bundle off the store. */
    public function retire(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $bundle = ProductBundle::findOrFail($id);

        abort_unless(in_array($bundle->status, [ProductBundle::STATUS_APPROVED, ProductBundle::STATUS_LIVE], true),
            422, 'هذه الحزمة ليست معروضة.');

        $bundle->update(['status' => ProductBundle::STATUS_RETIRED, 'retired_at' => now()]);

        return response()->json(['ok' => true]);
    }

    /* ─────────────────────────── payload ─────────────────────────── */

    private function row(ProductBundle $b): array
    {
        $codes = $b->items->pluck('item_code')->all();
        $products = Product::whereIn('item_code', $codes)->get()->keyBy('item_code');

        return [
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
            'floor_price' => (float) $b->floor_price,
            'savings_pct' => (float) $b->savings_pct,
            'stock_class' => $b->stock_class,
            'warehouse_scope' => $b->warehouse_scope,
            'score' => (float) $b->score,
            'rationale' => $b->rationale,
            'wc_product_id' => $b->wc_product_id,
            'rejected_reason' => $b->rejected_reason,
            'created_at' => optional($b->created_at)->toIso8601String(),
            'approved_at' => optional($b->approved_at)->toIso8601String(),
            'items' => $b->items->map(function ($it) use ($products) {
                $p = $products->get($it->item_code);
                return [
                    'item_code' => $it->item_code,
                    'name' => $it->item_name ?: ($p->item_name ?? $it->item_code),
                    'qty' => $it->qty,
                    'role' => $it->role,
                    'unit_retail' => (float) $it->unit_retail,
                    'image_url' => $this->productImageUrl($it->item_code, $p),
                ];
            })->values(),
        ];
    }

    /** First catalog image, else the standard image-host fallback (same as promotions). */
    private function productImageUrl(string $code, ?Product $p): string
    {
        $imgs = $p?->zb_images;
        if (is_string($imgs)) {
            $imgs = json_decode($imgs, true);
        }
        if (is_array($imgs) && ! empty($imgs[0])) {
            $first = $imgs[0];
            $url = is_array($first) ? ($first['src'] ?? $first['url'] ?? null) : $first;
            if (is_string($url) && $url !== '') {
                return $url;
            }
        }

        return "https://gal.holeno.com/imghd/{$code}.png";
    }
}
