<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Models\BrandDesignKitModel;
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
     * GET /api/woo/brand-kits — every brand identity the owner has on file, keyed
     * by SAP brand code. The app's brand page paints any brand in its own colours
     * and tells its story from this, published boutique or not.
     *
     * Raw stored values only — no HOUSE defaults — so a brand without a kit is
     * simply absent, and the store falls back to its own look instead of showing
     * the house mood line as if the brand had said it.
     */
    public function kits(Request $request): JsonResponse
    {
        $rows = BrandDesignKitModel::where('is_active', true)->get();
        $brands = Brand::all();
        $byCode = $brands->keyBy(fn ($b) => (string) $b->code);
        $byName = $brands->keyBy(fn ($b) => mb_strtolower(trim((string) $b->name)));

        $data = [];
        foreach ($rows as $row) {
            $key = trim((string) $row->brand_key);
            $brand = $byCode->get($key) ?? $byName->get(mb_strtolower($key));
            $code = $brand ? (string) $brand->code : (ctype_digit($key) ? $key : null);
            if ($code === null || $code === '') {
                continue;
            }
            $data[$code] = [
                'code' => $code,
                'name' => $brand->name ?? $row->brand_name,
                'accent' => $row->accent,
                'accent_dark' => $row->accent_dark,
                'gold' => $row->gold,
                'tagline_ar' => $row->tagline_ar,
                'tagline_en' => $row->tagline_en,
                'audience_ar' => $row->audience_ar,
                'mood_ar' => $row->mood_ar,
                'country' => $row->country,
                'founded' => $row->founded,
                'category' => $row->category,
                'positioning' => $row->positioning,
                'logo_url' => $row->logo_url ?: null,
            ];
        }

        return response()->json([
            'count' => count($data),
            'data' => (object) $data,
            'synced_at' => now()->toIso8601String(),
        ]);
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
