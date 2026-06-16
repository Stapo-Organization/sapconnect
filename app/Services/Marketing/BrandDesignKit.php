<?php

namespace App\Services\Marketing;

use App\Models\Brand;
use App\Models\BrandDesignKitModel;
use App\Models\MarketingCampaign;
use App\Models\Product;

/**
 * Resolves the design identity for a campaign's banner:
 *  - single-brand campaign → that brand's kit (house defaults + per-brand
 *    overrides + the brand's real logo/name)
 *  - multi-brand or store-feature → the Zooboxi HOUSE kit
 * Fonts referenced here must exist in resources/fonts (loaded by render-banner.mjs).
 */
class BrandDesignKit
{
    /** Per-brand override columns copied verbatim onto the kit (when non-null). */
    private const OVERRIDE_FIELDS = [
        'accent', 'accent_dark', 'gold', 'headline_font', 'body_font',
        'scene_style', 'imagery_style', 'imagery_notes', 'text_style_ar',
        'mood_ar', 'tagline_ar', 'audience_ar', 'do_not_ar',
        'positioning', 'category',
    ];

    /** Fixed brand_key for the store-feature (Zooboxi) identity in brand_design_kits. */
    public const STORE_KEY = 'zooboxi';

    /** Zooboxi house identity (the default + multi-brand/feature look). */
    public const HOUSE = [
        'headline_font' => 'Aref Ruqaa',  // calligraphic, premium
        'body_font' => 'Tajawal',         // clean, modern, readable
        'accent' => '#0d9488',
        'accent_dark' => '#0a5560',
        'gold' => '#F4BE2C',
        'logo_text' => 'منتجات',
        'logo_image' => null,
        'scene_style' => 'premium luxurious, warm teal and gold tones, elegant studio lighting',
        'imagery_style' => 'photographic',  // real product photography by default
        'imagery_notes' => 'clean real product photography on a premium surface',
        'text_style_ar' => 'elegant clean Arabic typography',
        'mood_ar' => 'فخم·دافئ·نظيف',
        'tagline_ar' => null,
        'audience_ar' => null,
        'do_not_ar' => null,
        'positioning' => null,
        'category' => null,
        'brand_name' => null,
    ];

    /** @return array<string,mixed> */
    public function forCampaign(MarketingCampaign $campaign): array
    {
        // Owner's explicit choice at approval time wins (PromotionController::approve).
        $identity = $campaign->design_identity ?: null; // 'brand' | 'zooboxi' | null (auto)
        if ($identity === 'zooboxi') {
            return $this->storeKit();
        }

        // Brand boutique campaigns are tied directly to a brand (no single product).
        if (! empty($campaign->brand_code)) {
            $brand = Brand::where('code', $campaign->brand_code)->first();
            if ($brand) {
                return $this->forBrand($brand);
            }
        }

        $codes = array_filter(array_merge([$campaign->item_code], $campaign->companion_item_codes ?? []));
        $products = Product::with('brand')->whereIn('item_code', $codes)->get();
        $brands = $products->pluck('brand')->filter()->unique('id')->values();

        if ($identity === 'brand') {
            // Force the brand look: prefer the main item's brand, else the first found.
            $brand = $this->primaryBrand($campaign, $products, $brands);
            return $brand ? $this->brandKit($brand) : $this->storeKit();
        }

        // Auto: exactly one brand → that brand; multi-brand or none → store identity.
        return $brands->count() === 1 ? $this->brandKit($brands->first()) : $this->storeKit();
    }

    /**
     * Product-independent resolver for the brand boutique pages (/brand/<slug>/):
     * the brand's full visual identity + story, used by BrandPageController and by
     * brand-page creative generation (campaigns carrying a brand_code).
     *
     * @return array<string,mixed>
     */
    public function forBrand(Brand $brand): array
    {
        return $this->brandKit($brand);
    }

    /**
     * Extra story columns surfaced for the brand page (no HOUSE default — null when
     * the brand has no kit row). The visual fields come from OVERRIDE_FIELDS above.
     */
    private const STORY_FIELDS = ['country', 'founded', 'palette_notes'];

    /** A single brand's kit: HOUSE defaults + the brand's real name/logo + any stored overrides. */
    private function brandKit($brand): array
    {
        $kit = self::HOUSE;
        $kit['brand_name'] = $brand->name ?? null;
        $kit['logo_image'] = $brand->image_url ?: null;
        foreach (self::STORY_FIELDS as $f) {
            $kit[$f] = null;
        }

        $override = BrandDesignKitModel::where('is_active', true)
            ->where(fn ($q) => $q->where('brand_key', $brand->code)->orWhere('brand_key', $brand->name))
            ->first();

        if ($override) {
            foreach (array_merge(self::OVERRIDE_FIELDS, self::STORY_FIELDS) as $f) {
                if (! empty($override->{$f})) {
                    $kit[$f] = $override->{$f};
                }
            }
            if (! empty($override->logo_url)) {
                $kit['logo_image'] = $override->logo_url;
            }
        }

        return $kit;
    }

    /** The brand to feature when the owner forces the 'brand' identity (main item first). */
    private function primaryBrand(MarketingCampaign $campaign, $products, $brands)
    {
        if ($campaign->item_code) {
            $main = $products->firstWhere('item_code', $campaign->item_code);
            if ($main && $main->brand) {
                return $main->brand;
            }
        }

        return $brands->first(); // may be null
    }

    /**
     * Store-feature identity (multi-brand / no-brand campaigns): the Zooboxi
     * HOUSE defaults overlaid with an optional brand_design_kits row keyed
     * STORE_KEY, so the store look is editable from data (seed it via
     * marketing:seed-brand-kits). Unseeded → plain HOUSE (behaviour unchanged).
     */
    private function storeKit(): array
    {
        $kit = self::HOUSE;

        $override = BrandDesignKitModel::where('is_active', true)
            ->where('brand_key', self::STORE_KEY)
            ->first();

        if ($override) {
            foreach (self::OVERRIDE_FIELDS as $f) {
                if (! empty($override->{$f})) {
                    $kit[$f] = $override->{$f};
                }
            }
            if (! empty($override->brand_name)) {
                $kit['brand_name'] = $override->brand_name;
                $kit['logo_text'] = $override->brand_name;
            }
            if (! empty($override->logo_url)) {
                $kit['logo_image'] = $override->logo_url;
            }
        }

        return $kit;
    }
}
