<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarketingCampaign;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Serves approved, live campaigns to the WooCommerce plugin (banner zones) and a
 * read-only performance rollup for the admin monitor. Protected by
 * AuthenticateWooToken. Only APPROVED creatives are exposed (auditor H2).
 */
class CampaignDeliveryController extends Controller
{
    /** GET /api/woo/campaigns/active — live campaigns + approved creatives by variant/format. */
    public function active(Request $request): JsonResponse
    {
        // Lazy activation: flip due 'scheduled' rows to 'active' on read.
        MarketingCampaign::where('status', 'scheduled')
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', now()))
            ->update(['status' => 'active']);

        $campaigns = MarketingCampaign::with(['creatives' => fn ($q) => $q->where('status', 'approved')])
            ->live()
            ->orderByDesc('priority')->orderByDesc('score')
            ->limit(50)->get();

        $wooIds = DB::table('products')
            ->whereIn('item_code', $campaigns->pluck('item_code')->filter()->all())
            ->pluck('woo_product_id', 'item_code');

        $data = $campaigns->map(function ($c) use ($wooIds) {
            $creatives = [];
            foreach ($c->creatives as $cr) {
                $creatives[$cr->variant][$cr->format] = $cr->final_url;
            }

            return [
                'id' => $c->id,
                'campaign_type' => $c->campaign_type,
                'scope' => $c->scope,
                'headline_ar' => $c->headline_ar,
                'subheadline_ar' => $c->subheadline_ar,
                'cta_ar' => $c->cta_ar,
                'badge_ar' => $c->badge_ar,
                'coupon_code' => $c->coupon_code,
                'discount_pct' => $c->discount_pct,
                'item_code' => $c->item_code,
                'woo_product_id' => $c->item_code ? ($wooIds[$c->item_code] ?? null) : null,
                'companion_item_codes' => $c->companion_item_codes,
                'zones' => $c->zones,
                'target_city' => $c->target_city,
                'target_express_only' => (bool) $c->target_express_only,
                'ab_enabled' => (bool) $c->ab_enabled,
                'starts_at' => $c->starts_at,
                'ends_at' => $c->ends_at,
                'creatives' => $creatives, // { A: { hero:url, wide:url, card:url, strip:url }, B: {...} }
            ];
        })->filter(fn ($row) => ! empty($row['creatives']))->values();

        return response()->json([
            'count' => $data->count(),
            'data' => $data,
            'synced_at' => now()->toIso8601String(),
        ]);
    }

    /** GET /api/woo/campaigns/performance — display-only rollup from store_events. */
    public function performance(Request $request): JsonResponse
    {
        $rows = DB::table('store_events')
            ->selectRaw("JSON_EXTRACT(payload, '$.campaign_id') as campaign_id, ab_variant, event_type, COUNT(*) as cnt")
            ->where('zone', 'like', 'campaign:%')
            ->groupBy('campaign_id', 'ab_variant', 'event_type')
            ->get();

        $byCampaign = [];
        foreach ($rows as $r) {
            $cid = (int) trim((string) $r->campaign_id, '"');
            if (! $cid) {
                continue;
            }
            $variant = $r->ab_variant ?: 'A';
            $byCampaign[$cid][$variant][$r->event_type] = (int) $r->cnt;
        }

        return response()->json(['data' => $byCampaign]);
    }
}
