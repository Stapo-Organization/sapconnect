<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\GenerateAdCreative;
use App\Models\CampaignCreative;
use App\Models\MarketingCampaign;
use App\Models\Product;
use App\Services\Marketing\AdPlacements;
use App\Services\Marketing\CampaignOfferGuard;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Owner-facing campaign review/approval API for the Flutter app. Owner-only
 * (Super Admin) — branch managers never reach it. Approval is transactional and
 * re-validates channel safety authoritatively (the app's checks are advisory).
 */
class PromotionController extends Controller
{
    public function __construct(private CampaignOfferGuard $guard) {}

    private function authorizeOwner(Request $request): void
    {
        abort_unless($request->user() && $request->user()->hasRole('Super Admin'), 403, 'مخصّص للمالك فقط.');
    }

    /** GET /api/promotions/summary — home-section badge + recent previews. */
    public function summary(Request $request): JsonResponse
    {
        $this->authorizeOwner($request);

        $pending = MarketingCampaign::where('status', 'suggested')->count();
        $active = MarketingCampaign::whereIn('status', ['scheduled', 'active'])->count();

        // Diverse top slice for the Home slider: the strongest few per type,
        // then the best 12 overall — so the teaser shows variety, not one type.
        $recent = MarketingCampaign::with('creatives')
            ->where('status', 'suggested')
            ->orderByDesc('score')
            ->get()
            ->groupBy('campaign_type')
            ->flatMap(fn ($g) => $g->take(3))
            ->sortByDesc('score')
            ->take(12)
            ->values();

        return response()->json([
            'pending_count' => $pending,
            'active_count' => $active,
            'campaigns' => $recent->map(fn ($c) => $this->summaryRow($c)),
        ]);
    }

    /** GET /api/promotions?status= — list by status. */
    public function index(Request $request): JsonResponse
    {
        $this->authorizeOwner($request);

        $status = $request->query('status', 'suggested');
        $query = MarketingCampaign::with('creatives');

        if ($status === 'ended') {
            $rows = $query->whereIn('status', ['ended', 'rejected'])->latest()->limit(300)->get();
        } elseif ($status === 'suggested') {
            // "Needs owner action" = concept (suggested) + preview (approved, awaiting
            // publish). Raw `score` is NOT comparable across types (bundle lift*25 dwarfs
            // clearance LPS / spotlight composite), so a plain global sort would bury whole
            // types below the 100-row cap. Pull every type's full pool, then round-robin by
            // type (each type strongest-first) so the best of EVERY type surfaces at the top.
            $rows = $query->whereIn('status', ['suggested', 'approved'])
                ->orderByDesc('score')->limit(400)->get();
            $byType = $rows->groupBy('campaign_type')->map->values();
            $deepest = $byType->map->count()->max() ?? 0;
            $rows = collect();
            for ($rank = 0; $rank < $deepest; $rank++) {
                foreach ($byType as $group) {
                    if ($group->has($rank)) {
                        $rows->push($group[$rank]);
                    }
                }
            }
        } else {
            $rows = $query->where('status', $status)->latest()->limit(300)->get();
        }

        return response()->json([
            'data' => $rows->map(fn ($c) => $this->summaryRow($c)),
        ]);
    }

    /** GET /api/promotions/{id} — full detail + creatives + safety block. */
    public function show(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $c = MarketingCampaign::with('creatives')->findOrFail($id);

        return response()->json(['data' => $this->detail($c)]);
    }

    /** GET /api/promotions/placements — available ad slots for the placement picker. */
    public function placements(Request $request): JsonResponse
    {
        $this->authorizeOwner($request);
        return response()->json(['data' => AdPlacements::all()]);
    }

    /**
     * POST /api/promotions/{id}/approve — owner approves the CONCEPT, picks a
     * placement and (optionally) edits the copy. This is when the single creative
     * (sized for the placement) is generated — NOT live yet (status = approved =
     * preview). The owner then publishes after reviewing it.
     */
    public function approve(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);

        $data = $request->validate([
            'placement' => 'required|string|max:40',
            'design_identity' => 'nullable|in:auto,brand,zooboxi',
            'headline' => 'nullable|string|max:255',
            'subheadline' => 'nullable|string|max:255',
            'cta' => 'nullable|string|max:80',
        ]);

        if (! AdPlacements::exists($data['placement'])) {
            return response()->json(['message' => 'موقع غير معروف.'], 422);
        }

        $c = MarketingCampaign::findOrFail($id);
        $c->fill(array_filter([
            'headline_ar' => $data['headline'] ?? null,
            'subheadline_ar' => $data['subheadline'] ?? null,
            'cta_ar' => $data['cta'] ?? null,
        ], fn ($v) => $v !== null));
        $c->scope = 'visibility';
        $c->placement = $data['placement'];
        // Owner's design-identity choice ('auto' clears the override → resolver decides).
        $identity = $data['design_identity'] ?? null;
        $c->design_identity = $identity === 'auto' ? null : $identity;
        $c->zones = array_values(array_filter([AdPlacements::zoneFor($data['placement'])]));
        $c->status = 'approved'; // preview — not served to the store until published
        $c->save();

        // Fresh single-format creative for the chosen placement (preview).
        CampaignCreative::where('campaign_id', $c->id)->delete();
        GenerateAdCreative::dispatchAfterResponse($c->id);

        return response()->json(['data' => $this->detail($c->fresh('creatives'))]);
    }

    /**
     * POST /api/promotions/{id}/publish — push the previewed creative live into its
     * placement. Enforces one active campaign per placement (ends the others).
     */
    public function publish(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $data = $request->validate([
            'variant' => 'nullable|in:A,B',
            'start_at' => 'nullable|date',
            'end_at' => 'nullable|date|after_or_equal:start_at',
        ]);

        $c = MarketingCampaign::with('creatives')->findOrFail($id);
        if (! $c->placement) {
            return response()->json(['message' => 'لم يُحدَّد موقع للإعلان بعد.'], 422);
        }
        $variant = $data['variant'] ?? 'A';
        $hasReady = $c->creatives->where('variant', $variant)->whereIn('status', ['ready', 'approved', 'selected'])->isNotEmpty();
        if (! $hasReady) {
            return response()->json(['message' => 'لا يوجد تصميم جاهز للنشر.'], 422);
        }

        $result = DB::transaction(function () use ($c, $data, $variant, $request) {
            $start = isset($data['start_at']) ? \Carbon\Carbon::parse($data['start_at']) : now();
            $end = isset($data['end_at']) ? \Carbon\Carbon::parse($data['end_at'])
                : now()->addDays((int) ($this->settingDuration()));

            // One active campaign per placement → end any other live one in this slot.
            MarketingCampaign::where('placement', $c->placement)->where('id', '!=', $c->id)
                ->whereIn('status', ['active', 'scheduled'])->update(['status' => 'ended']);

            CampaignCreative::where('campaign_id', $c->id)->where('variant', $variant)
                ->whereIn('status', ['ready', 'selected', 'approved'])->update(['status' => 'approved']);

            $c->scope = 'visibility';
            $c->starts_at = $start;
            $c->ends_at = $end;
            $c->status = $start->lessThanOrEqualTo(now()) ? 'active' : 'scheduled';
            $c->owner_approved_by = $request->user()->id;
            $c->owner_approved_at = now();
            $c->published_at = now();
            $c->save();

            return $c;
        });

        return response()->json([
            'published' => in_array($result->status, ['active', 'scheduled'], true),
            'data' => $this->detail($result->fresh('creatives')),
        ]);
    }

    /**
     * POST /api/promotions/{id}/reject — captures structured feedback (a coarse
     * category + free-text reason) so rejections can later be analysed to improve
     * the generator.
     */
    public function reject(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $data = $request->validate([
            'reason' => 'nullable|string|max:500',
            'category' => 'nullable|string|max:40',
        ]);

        $c = MarketingCampaign::findOrFail($id);
        $c->update([
            'status' => 'rejected',
            'rejected_reason' => $data['reason'] ?? null,
            'rejected_category' => $data['category'] ?? null,
        ]);

        return response()->json(['data' => ['id' => $c->id, 'status' => 'rejected']]);
    }

    /** POST /api/promotions/{id}/regenerate — re-render creatives (fresh roll). */
    public function regenerate(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $c = MarketingCampaign::findOrFail($id);

        // Invalidate idempotency so the job re-renders, mark generating for UI polling.
        CampaignCreative::where('campaign_id', $c->id)->update(['content_hash' => null, 'status' => 'generating']);
        // afterResponse: prod queue is sync, so run AFTER returning (the request must
        // not block for the ~minutes gpt-image takes). The app polls until ready.
        GenerateAdCreative::dispatchAfterResponse($c->id);

        return response()->json(['data' => ['id' => $c->id, 'regenerating' => true]]);
    }

    /**
     * POST /api/promotions/{id}/refine — re-render the creative to the owner's note.
     * The note is appended to the gpt-image-2 prompt; the app polls until ready.
     */
    public function refine(Request $request, int $id): JsonResponse
    {
        $this->authorizeOwner($request);
        $data = $request->validate(['note' => 'required|string|max:600']);

        $c = MarketingCampaign::findOrFail($id);
        $c->update(['refinement_note' => trim($data['note'])]);

        CampaignCreative::where('campaign_id', $c->id)->update(['content_hash' => null, 'status' => 'generating']);
        GenerateAdCreative::dispatchAfterResponse($c->id);

        return response()->json(['data' => ['id' => $c->id, 'regenerating' => true]]);
    }

    // ── helpers ────────────────────────────────────────────────

    private function summaryRow(MarketingCampaign $c): array
    {
        // Any ready creative (placement-driven campaigns may have only a hero).
        $thumb = $c->creatives->firstWhere('format', 'card')
            ?? $c->creatives->firstWhere('status', 'approved')
            ?? $c->creatives->first();
        return [
            'id' => $c->id,
            'campaign_type' => $c->campaign_type,
            'scope' => $c->scope,
            'status' => $c->status,
            'headline_ar' => $c->headline_ar,
            'reason' => $c->reason,
            'item_code' => $c->item_code,
            'companion_item_codes' => $c->companion_item_codes,
            'products' => $this->campaignProducts($c), // real catalog images for the feed
            'rationale' => $c->rationale,               // signal chips
            'placement' => $c->placement,
            'thumb_url' => $thumb?->thumb_url ?? $thumb?->final_url,
            'created_at' => $c->created_at,
        ];
    }

    private function detail(MarketingCampaign $c): array
    {
        $floor = $c->item_code
            ? $this->guard->lineFor((string) $c->item_code)
            : ['floor' => null, 'retail' => null, 'base' => null];

        return [
            'id' => $c->id,
            'campaign_type' => $c->campaign_type,
            'scope' => $c->scope,
            'status' => $c->status,
            'item_code' => $c->item_code,
            'companion_item_codes' => $c->companion_item_codes,
            'products' => $this->campaignProducts($c),
            'placement' => $c->placement,
            'design_identity' => $c->design_identity,            // owner override: null|brand|zooboxi
            'brand_name' => $this->campaignBrandName($c),        // labels the "brand" identity option (null = no brand)
            'refinement_note' => $c->refinement_note,
            'headline_ar' => $c->headline_ar,
            'subheadline_ar' => $c->subheadline_ar,
            'cta_ar' => $c->cta_ar,
            'badge_ar' => $c->badge_ar,
            'reason' => $c->reason,
            'rationale' => $c->rationale,
            'zones' => $c->zones,
            'discount_pct' => $c->discount_pct,
            'coupon_code' => $c->coupon_code,
            'starts_at' => $c->starts_at,
            'ends_at' => $c->ends_at,
            'ab_enabled' => $c->ab_enabled,
            'safety' => [
                'floor_price' => $floor['floor'] ?? null,
                'retail_price' => $floor['retail'] ?? null,
                'base_price' => $floor['base'] ?? null,
                'max_discount_pct' => $this->guard->evaluate('coupon', null, $c->item_code ? [$this->guard->lineFor((string) $c->item_code)] : [])['max_discount_pct'],
                // visibility is always wholesale-safe
                'floor_safe' => $c->scope === 'visibility' ? true : null,
            ],
            'creatives' => $c->creatives->map(fn ($cr) => [
                'id' => $cr->id,
                'format' => $cr->format,
                'variant' => $cr->variant,
                'status' => $cr->status,
                'final_url' => $cr->final_url,
                'thumb_url' => $cr->thumb_url,
            ])->values(),
        ];
    }

    /** The real products a campaign is about (main item + bundle companions). */
    private function campaignProducts(MarketingCampaign $c): array
    {
        $codes = array_values(array_filter(array_merge([$c->item_code], $c->companion_item_codes ?? [])));
        if (empty($codes)) {
            return [];
        }
        $byCode = Product::whereIn('item_code', $codes)->get()->keyBy('item_code');

        return array_map(function ($code) use ($byCode) {
            $p = $byCode->get($code);
            return [
                'item_code' => $code,
                'name' => $p->item_name ?? $p->name ?? $code,
                'image_url' => $this->productImageUrl($code, $p),
            ];
        }, $codes);
    }

    /** Primary brand name behind a campaign (main item's brand, else first found); null if none. */
    private function campaignBrandName(MarketingCampaign $c): ?string
    {
        $codes = array_values(array_filter(array_merge([$c->item_code], $c->companion_item_codes ?? [])));
        if (empty($codes)) {
            return null;
        }
        $products = Product::with('brand')->whereIn('item_code', $codes)->get();
        $brands = $products->pluck('brand')->filter()->unique('id')->values();
        if ($brands->isEmpty()) {
            return null;
        }
        if ($c->item_code) {
            $main = $products->firstWhere('item_code', $c->item_code);
            if ($main && $main->brand) {
                return $main->brand->name;
            }
        }
        return $brands->first()->name;
    }

    /** First catalog image for a product, else the standard image-host fallback. */
    private function productImageUrl(string $code, ?Product $p): ?string
    {
        $imgs = $p?->zb_images;
        if (is_string($imgs)) {
            $imgs = json_decode($imgs, true);
        }
        if (is_array($imgs) && ! empty($imgs)) {
            $first = $imgs[0];
            $url = is_array($first) ? ($first['src'] ?? $first['url'] ?? null) : (is_string($first) ? $first : null);
            if ($url) {
                return $url;
            }
        }
        return "https://gal.holeno.com/imghd/{$code}.png";
    }

    private function settingDuration(): int
    {
        $v = \App\Models\ZooboxiSetting::where('key', 'mkt_default_duration_days')->value('value');
        return $v !== null ? (int) $v : 7;
    }
}
