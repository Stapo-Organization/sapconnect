<?php

namespace App\Services\Marketing;

/**
 * Where a campaign's banner can appear. Each placement defines the creative
 * FORMAT (and therefore the gpt-image-2 aspect ratio) so we render exactly one
 * image at the right size for the chosen slot. One active campaign per placement.
 *
 * Start with a single slot (home_banner_1); more (brand page, cats page, …) are
 * added here later without touching the generator or the app.
 */
class AdPlacements
{
    /** key => [label_ar, format (hero|wide|card|strip), zone (store hook)]. */
    public const PLACEMENTS = [
        'home_banner_1' => [
            'label_ar' => 'بانر الرئيسية ١',
            'format' => 'hero',     // 3:2 wide banner
            'zone' => 'hero',
        ],

        // ── Mobile app (Zooboxi customer app) ──────────────────────────────
        // App-only zones: the store website ignores them, the app's /v2/home
        // reads them. Formats reuse the existing pipeline (hero renders 3:2 on
        // the gpt-image path, wide is the in-feed strip) — no generator changes.
        'app_home_hero' => [
            'label_ar' => 'سلايدر التطبيق الرئيسي',
            'format' => 'hero',     // 3:2 — fills the app hero carousel card
            'zone' => 'app_hero',
        ],
        'app_home_banner_1' => [
            'label_ar' => 'بانر التطبيق ١',
            'format' => 'wide',     // in-feed banner between app rails
            'zone' => 'app_banner',
        ],
        'app_home_banner_2' => [
            'label_ar' => 'بانر التطبيق ٢',
            'format' => 'wide',
            'zone' => 'app_banner',
        ],

        // ── Brand boutique pages (/brand/<slug>/) ──────────────────────────
        // One brand hero (3:2) + up to three square promo tiles, each rendered
        // by gpt-image-2 in the brand's own identity. Served per-brand by
        // CampaignDeliveryController-style /api/woo/brands, keyed by brand_code.
        'brand_hero' => [
            'label_ar' => 'بانر صفحة العلامة',
            'format' => 'hero',     // 3:2 brand-world banner
            'zone' => 'brand_hero',
        ],
        'brand_tile_1' => [
            'label_ar' => 'تايل العلامة ١',
            'format' => 'card',     // 1:1 promo tile
            'zone' => 'brand_tile',
        ],
        'brand_tile_2' => [
            'label_ar' => 'تايل العلامة ٢',
            'format' => 'card',
            'zone' => 'brand_tile',
        ],
        'brand_tile_3' => [
            'label_ar' => 'تايل العلامة ٣',
            'format' => 'card',
            'zone' => 'brand_tile',
        ],
    ];

    /** Placement keys that drive a brand boutique page (vs. product campaigns). */
    public const BRAND_PLACEMENTS = ['brand_hero', 'brand_tile_1', 'brand_tile_2', 'brand_tile_3'];

    public static function isBrand(?string $key): bool
    {
        return $key !== null && in_array($key, self::BRAND_PLACEMENTS, true);
    }

    /** @return array<int,array{key:string,label_ar:string,format:string,zone:string}> */
    public static function all(): array
    {
        $out = [];
        foreach (self::PLACEMENTS as $key => $p) {
            $out[] = ['key' => $key] + $p;
        }
        return $out;
    }

    public static function exists(?string $key): bool
    {
        return $key !== null && isset(self::PLACEMENTS[$key]);
    }

    /** Creative format for a placement (defaults to hero). */
    public static function formatFor(?string $key): string
    {
        return self::PLACEMENTS[$key]['format'] ?? 'hero';
    }

    public static function zoneFor(?string $key): ?string
    {
        return self::PLACEMENTS[$key]['zone'] ?? null;
    }
}
