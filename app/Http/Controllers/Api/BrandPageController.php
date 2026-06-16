<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Models\MarketingCampaign;
use App\Services\Marketing\BrandDesignKit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Serves the per-brand boutique pages (/brand/<slug>/) to the WooCommerce plugin.
 * Protected by AuthenticateWooToken. Returns each brand's resolved visual identity
 * (colors/fonts/story) + the owner-approved AI hero/tile banner URLs.
 *
 * Channel-safe by construction: brand pages are visibility-only — NO price,
 * discount or coupon is ever emitted here. Only APPROVED creatives are exposed.
 */
class BrandPageController extends Controller
{
    public function __construct(private BrandDesignKit $kit) {}

    /**
     * GET /api/woo/brands — every brand with a PUBLISHED page (≥1 live approved
     * brand creative). The store gates its /brand/<slug>/ takeover on this set, so
     * an unpublished brand keeps the default WooCommerce archive.
     */
    public function index(Request $request): JsonResponse
    {
        // Lazy activation: flip due scheduled brand campaigns to active on read.
        MarketingCampaign::where('status', 'scheduled')->whereNotNull('brand_code')
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', now()))
            ->update(['status' => 'active']);

        $byBrand = MarketingCampaign::with(['creatives' => fn ($q) => $q->where('status', 'approved')])
            ->live()->whereNotNull('brand_code')->where('scope', 'visibility')
            ->get()->groupBy('brand_code');

        $brands = Brand::whereIn('code', $byBrand->keys()->all())->get()->keyBy('code');

        $data = [];
        foreach ($byBrand as $code => $group) {
            $brand = $brands->get($code);
            if (! $brand) {
                continue;
            }
            $payload = $this->brandPayload($brand, $group);
            // Only surface a brand once it actually has a banner to show.
            if ($payload['hero_url'] || ! empty($payload['tiles'])) {
                $data[] = $payload;
            }
        }

        return response()->json([
            'count' => count($data),
            'data' => array_values($data),
            'synced_at' => now()->toIso8601String(),
        ]);
    }

    /**
     * GET /api/woo/brands/{code}/page — a single brand. Always resolves the kit
     * (even with NO AI yet → hero_url=null, tiles=[]) so store theming works for any
     * brand and the Filament preview can read it.
     */
    public function show(Request $request, string $code): JsonResponse
    {
        $brand = Brand::where('code', $code)->first();
        if (! $brand) {
            return response()->json(['message' => 'Brand not found'], 404);
        }

        $group = MarketingCampaign::with(['creatives' => fn ($q) => $q->where('status', 'approved')])
            ->live()->where('brand_code', $code)->where('scope', 'visibility')->get();

        return response()->json(['data' => $this->brandPayload($brand, $group)]);
    }

    /**
     * @param  \Illuminate\Support\Collection<int,MarketingCampaign>  $campaigns
     * @return array<string,mixed>
     */
    private function brandPayload(Brand $brand, $campaigns): array
    {
        $kit = $this->kit->forBrand($brand);

        $heroUrl = null;
        $tiles = [];
        foreach ($campaigns as $c) {
            $creative = $c->creatives->first();
            if (! $creative || ! $creative->final_url) {
                continue;
            }
            if ($c->placement === 'brand_hero') {
                $heroUrl = $creative->final_url;
            } elseif (str_starts_with((string) $c->placement, 'brand_tile_')) {
                $tiles[$c->placement] = [
                    'url' => $creative->final_url,
                    'headline_ar' => $c->headline_ar,
                    'cta_ar' => $c->cta_ar,
                ];
            }
        }
        ksort($tiles); // brand_tile_1, _2, _3 order

        return [
            'code' => (string) $brand->code,
            'name' => $brand->name,
            'logo_url' => $kit['logo_image'] ?? null,
            'hero_url' => $heroUrl,
            'tiles' => array_values($tiles),
            'kit' => [
                'accent' => $kit['accent'] ?? null,
                'accent_dark' => $kit['accent_dark'] ?? null,
                'gold' => $kit['gold'] ?? null,
                'headline_font' => $kit['headline_font'] ?? null,
                'body_font' => $kit['body_font'] ?? null,
                'tagline_ar' => $kit['tagline_ar'] ?? null,
                'audience_ar' => $kit['audience_ar'] ?? null,
                'mood_ar' => $kit['mood_ar'] ?? null,
                'country' => $kit['country'] ?? null,
                'founded' => $kit['founded'] ?? null,
                'positioning' => $kit['positioning'] ?? null,
                'category' => $kit['category'] ?? null,
            ],
        ];
    }
}
