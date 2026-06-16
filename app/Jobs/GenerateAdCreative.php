<?php

namespace App\Jobs;

use App\Models\CampaignCreative;
use App\Models\MarketingCampaign;
use App\Models\Product;
use App\Services\Creative\ImageGeneratorInterface;
use App\Services\Creative\ImageGeneratorManager;
use App\Services\Marketing\AdPromptBuilder;
use App\Services\Marketing\BannerCompositor;
use Illuminate\Support\Facades\Http;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Renders a campaign's creatives: ONE AI visual base per A/B variant, composited
 * into every banner format (cost-efficient — 1 AI call → many banners). Writes
 * campaign_creatives rows as status='ready'. Idempotent via content_hash (which
 * includes the resolved offer/copy, so an edited offer re-renders). Honors a
 * daily generation cap; falls back to the placeholder driver beyond it.
 */
class GenerateAdCreative implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public array $backoff = [30, 120, 300];

    /** Formats rendered for every campaign (all share one AI base per variant). */
    public const FORMATS = ['hero', 'wide', 'card', 'strip'];

    public function __construct(public int $campaignId)
    {
        $this->onQueue('creatives');
    }

    public function handle(ImageGeneratorManager $images, BannerCompositor $compositor): void
    {
        $campaign = MarketingCampaign::find($this->campaignId);
        if (! $campaign) {
            return;
        }

        $variants = $campaign->ab_enabled ? ['A', 'B'] : ['A'];
        $driverName = $this->resolveDriver();
        $productImages = $this->productImages($campaign);
        $hasProduct = ! empty($productImages);
        $kit = (new \App\Services\Marketing\BrandDesignKit())->forCampaign($campaign);

        // gpt-image-2 renders the COMPLETE finished banner (scene + product + Arabic
        // + logo) — a different pipeline from the nano/Imagen + resvg compositor path.
        if ($driverName === 'gpt-image') {
            $this->handleGptImage($campaign, $images->driver($driverName), $variants, $productImages, $kit);
            return;
        }

        foreach ($variants as $i => $variant) {
            $hash = $this->contentHash($campaign, $variant, $productImages, $kit);

            // idempotent: skip if a ready/approved creative already matches this hash
            $existing = CampaignCreative::where('campaign_id', $campaign->id)
                ->where('variant', $variant)
                ->whereIn('status', ['ready', 'approved', 'selected'])
                ->where('content_hash', $hash)
                ->exists();
            if ($existing) {
                continue;
            }

            $driver = $images->driver($driverName);
            $prompt = $this->scenePrompt($campaign, $hasProduct, $kit);
            // nano-banana (scene) gets the real product images; Imagen (txt2img) gets none.
            $base = $driver->generate($prompt, [
                'image_inputs' => $productImages,
                'aspect_ratio' => '16:9',
                'seed' => $variant === 'B' ? 7 : null,
            ]);

            foreach (self::FORMATS as $format) {
                // The scene already contains the product → no separate product overlay.
                $this->renderFormat($compositor, $campaign, $variant, $format, $base, $driver->key(), $prompt, $hash, $kit);
            }
        }
    }

    /**
     * gpt-image-2 path: render finished banners (scene + product + Arabic + logo)
     * directly — two shapes (3:2 hero, 1:1 card) cover all store formats; the hero
     * also serves the wide/strip zones (the store renders them responsively).
     */
    private function handleGptImage(
        MarketingCampaign $campaign,
        ImageGeneratorInterface $driver,
        array $variants,
        array $productImages,
        array $kit,
    ): void {
        $builder = new AdPromptBuilder();
        // Drop product images that 404 (e.g. items with no catalog photo) — a broken
        // input_image makes the whole gpt-image-2 prediction fail. Falls back to a
        // product-free brand scene if none resolve.
        $productImages = $this->verifiedImages($productImages);
        $logoUrl = $this->verifiedLogoUrl($kit['logo_image'] ?? null);
        $species = $this->resolveSpecies($campaign, $kit);
        $shapeForFormat = ['hero' => 'hero', 'wide' => 'hero', 'strip' => 'hero', 'card' => 'card'];

        // Generate ONLY the format(s) the placement needs (one image). Falls back to
        // all formats when no placement is set (legacy / un-placed campaigns).
        $targetFormats = $campaign->placement
            ? [\App\Services\Marketing\AdPlacements::formatFor($campaign->placement)]
            : self::FORMATS;
        $neededShapes = array_values(array_unique(array_map(fn ($f) => $shapeForFormat[$f] ?? 'hero', $targetFormats)));

        foreach ($variants as $variant) {
            $ctx = [
                'product_count' => count($productImages),
                'has_logo' => (bool) $logoUrl,
                'species_scene' => $species['scene'],
                'brand_name' => $kit['brand_name'] ?? 'منتجات',
            ];
            $hash = $this->gptHash($campaign, $variant, $productImages, $logoUrl, $kit, $species);

            $alreadyReady = CampaignCreative::where('campaign_id', $campaign->id)
                ->where('variant', $variant)
                ->whereIn('status', ['ready', 'approved', 'selected'])
                ->where('content_hash', $hash)
                ->count();
            if ($alreadyReady >= count($targetFormats)) {
                continue;
            }

            // Brand boutique campaigns sell the whole brand world (logo/palette/mood),
            // not one product → a different prompt recipe.
            $isBrand = ! empty($campaign->brand_code)
                || \App\Services\Marketing\AdPlacements::isBrand($campaign->placement);

            // Generate each unique shape once, then map the target formats onto them.
            $prompts = [];
            $shapePath = [];
            foreach ($neededShapes as $shape) {
                $prompt = $isBrand
                    ? $builder->buildBrandPage($campaign, $kit, $shape, $ctx)
                    : $builder->build($campaign, $kit, $shape, $ctx);
                if ($variant === 'B') {
                    $prompt .= ' Use an alternative composition and color emphasis for A/B variation.';
                }
                $prompts[$shape] = $prompt;
                $shapePath[$shape] = $driver->generate($prompt, [
                    'image_inputs' => $this->inputsFor($shape, $productImages, $logoUrl),
                    'aspect_ratio' => $builder->aspectFor($shape),
                    'quality' => 'high',
                ]);
            }

            foreach ($targetFormats as $format) {
                $shape = $shapeForFormat[$format] ?? 'hero';
                $this->storeFinishedCreative($campaign, $variant, $format, $shapePath[$shape] ?? null, $driver->key(), $prompts[$shape], $hash);
            }
        }
    }

    /** Persist a finished gpt-image banner into the stable per-format path. */
    private function storeFinishedCreative(
        MarketingCampaign $campaign,
        string $variant,
        string $format,
        ?string $absPath,
        string $driverKey,
        string $prompt,
        string $hash,
    ): void {
        $creative = CampaignCreative::firstOrNew([
            'campaign_id' => $campaign->id,
            'format' => $format,
            'variant' => $variant,
        ]);
        $creative->fill([
            'status' => 'generating',
            'driver' => $driverKey,
            'headline_ar' => $campaign->headline_ar,
            'subheadline_ar' => $campaign->subheadline_ar,
            'cta_ar' => $campaign->cta_ar,
            'badge_ar' => $campaign->badge_ar,
            'prompt' => $prompt,
            'content_hash' => $hash,
            'attempts' => (int) $creative->attempts + 1,
        ]);
        $creative->save();

        if (! $absPath || ! is_file($absPath)) {
            $creative->update(['status' => 'failed', 'error' => 'gpt-image generation failed']);
            Log::error('[creative] gpt-image failed', ['campaign' => $campaign->id, 'format' => $format, 'variant' => $variant]);
            return;
        }

        $relative = "creatives/{$campaign->id}/{$format}-{$variant}.png";
        Storage::disk('public')->put($relative, (string) file_get_contents($absPath));
        $abs = Storage::disk('public')->path($relative);
        $v = '?v=' . (is_file($abs) ? filemtime($abs) : time());
        $url = Storage::disk('public')->url($relative);
        $creative->update([
            'status' => 'ready',
            'final_url' => $url . $v,
            'thumb_url' => $url . $v,
            'base_image_url' => $url,
            'error' => null,
        ]);
    }

    /** Input images for a shape: products (+ brand logo LAST, referenced by the prompt). */
    private function inputsFor(string $shape, array $productImages, ?string $logoUrl): array
    {
        $imgs = $shape === 'card' ? array_slice($productImages, 0, 1) : array_slice($productImages, 0, 4);
        if ($logoUrl) {
            $imgs[] = $logoUrl;
        }
        return array_values(array_filter($imgs));
    }

    /** Keep only image URLs that actually resolve (a broken input fails the whole prediction). */
    private function verifiedImages(array $urls): array
    {
        return array_values(array_filter($urls, fn ($u) => $this->urlOk($u)));
    }

    /** Only pass a logo to the model if it actually resolves (many brand logos 404). */
    private function verifiedLogoUrl(?string $url): ?string
    {
        return $this->urlOk($url) ? $url : null;
    }

    /** Lightweight reachability check (Range request avoids downloading the full image). */
    private function urlOk(?string $url): bool
    {
        if (! $url) {
            return false;
        }
        try {
            return Http::timeout(10)->withHeaders(['Range' => 'bytes=0-0'])->get($url)->successful();
        } catch (\Throwable $e) {
            return false;
        }
    }

    /**
     * Species of the campaign's products → correct on-screen animal + Arabic pet-noun.
     * Mixed/unknown collapses to a neutral pet (never wrongly says "for your dog").
     *
     * @return array{noun:string,scene:string}
     */
    private function resolveSpecies(MarketingCampaign $campaign, array $kit): array
    {
        $codes = array_filter(array_merge([$campaign->item_code], $campaign->companion_item_codes ?? []));

        // Brand page: the kit's curated category is the most on-brand species signal;
        // otherwise sample the brand's products.
        if (empty($codes) && ! empty($campaign->brand_code)) {
            if (! empty($kit['category'])) {
                return $this->speciesProfile((string) $kit['category']);
            }
            $codes = Product::where('items_group_code', $campaign->brand_code)->limit(60)->pluck('item_code')->all();
        }

        $hay = mb_strtolower((string) Product::whereIn('item_code', $codes)->pluck('item_name')->filter()->implode(' '));

        $map = [
            'cat' => ['cat', 'kitten', 'kitty', 'قط', 'هرة', 'هرر'],
            'dog' => ['dog', 'puppy', 'canine', 'كلب', 'جرو'],
            'bird' => ['bird', 'parrot', 'canary', 'budgie', 'cockatiel', 'طير', 'ببغاء', 'كناري', 'عصاف'],
            'small_pet' => ['rabbit', 'hamster', 'guinea', 'ferret', 'أرنب', 'هامستر', 'قارض'],
            'fish' => ['fish', 'aquarium', 'سمك', 'أسماك', 'حوض'],
        ];
        $found = [];
        foreach ($map as $sp => $kws) {
            foreach ($kws as $k) {
                if ($k !== '' && str_contains($hay, $k)) {
                    $found[$sp] = true;
                    break;
                }
            }
        }
        $species = array_keys($found);
        if (count($species) === 1) {
            return $this->speciesProfile($species[0]);
        }
        if (count($species) > 1) {
            return $this->speciesProfile('mixed');
        }
        return $this->speciesProfile((string) ($kit['category'] ?? 'mixed'));
    }

    /** @return array{noun:string,scene:string} */
    private function speciesProfile(string $sp): array
    {
        return match ($sp) {
            'cat' => ['noun' => 'لقطتك', 'scene' => 'a calm, well-groomed real cat'],
            'dog' => ['noun' => 'لكلبك', 'scene' => 'a healthy, happy real dog'],
            'bird' => ['noun' => 'لطيرك', 'scene' => 'a vivid, lively real pet bird'],
            'small_pet' => ['noun' => 'لأليفك', 'scene' => 'a cute small pet (rabbit or hamster)'],
            'fish' => ['noun' => 'لأسماكك', 'scene' => 'a clean, vibrant aquarium scene'],
            'litter', 'grooming', 'health', 'accessories' => ['noun' => 'لأليفك', 'scene' => 'a happy, clean pet (a cat or a dog)'],
            default => ['noun' => 'لأليفك', 'scene' => 'happy pets (a cat and a dog together)'],
        };
    }

    /** Content hash for the gpt-image path (re-render when copy/kit/products/logo change). */
    private function gptHash(MarketingCampaign $campaign, string $variant, array $productImages, ?string $logoUrl, array $kit, array $species): string
    {
        return sha1(json_encode([
            $campaign->headline_ar, $campaign->subheadline_ar, $campaign->cta_ar, $campaign->badge_ar,
            $campaign->scope, $campaign->discount_pct, $campaign->coupon_code,
            $campaign->brand_code, $campaign->placement,
            $productImages, $logoUrl, $variant,
            $kit['accent'] ?? null, $kit['gold'] ?? null, $kit['scene_style'] ?? null,
            $kit['imagery_style'] ?? null, $kit['do_not_ar'] ?? null, $kit['brand_name'] ?? null,
            $species['scene'], $campaign->refinement_note,
            'gpt-image', (string) config('services.replicate.gpt_image_model'), (string) config('services.replicate.gpt_image_quality'),
        ]));
    }

    private function renderFormat(
        BannerCompositor $compositor,
        MarketingCampaign $campaign,
        string $variant,
        string $format,
        ?string $base,
        string $driverKey,
        string $prompt,
        string $hash,
        array $kit,
    ): void {
        $relative = "creatives/{$campaign->id}/{$format}-{$variant}.png";

        $creative = CampaignCreative::firstOrNew([
            'campaign_id' => $campaign->id,
            'format' => $format,
            'variant' => $variant,
        ]);
        $creative->fill([
            'status' => 'generating',
            'driver' => $driverKey,
            'headline_ar' => $campaign->headline_ar,
            'subheadline_ar' => $campaign->subheadline_ar,
            'cta_ar' => $campaign->cta_ar,
            'badge_ar' => $campaign->badge_ar,
            'prompt' => $prompt,
            'content_hash' => $hash,
            'attempts' => (int) $creative->attempts + 1,
        ]);
        $creative->save();

        $png = $compositor->render(
            $format,
            [
                'headline' => (string) $campaign->headline_ar,
                'subheadline' => (string) $campaign->subheadline_ar,
                'cta' => (string) $campaign->cta_ar,
                'badge' => (string) $campaign->badge_ar,
            ],
            $base,
            null, // product is already in the AI scene
            [
                'path' => $relative,
                'accent' => $kit['accent'],
                'accent_dark' => $kit['accent_dark'],
                'gold' => $kit['gold'],
                'headline_font' => $kit['headline_font'],
                'body_font' => $kit['body_font'],
                'logo_image' => $kit['logo_image'] ?? null,
                'logo_text' => $kit['logo_text'] ?? 'منتجات',
            ],
        );

        if (! $png) {
            $creative->update(['status' => 'failed', 'error' => 'compositor failed']);
            Log::error('[creative] render failed', ['campaign' => $campaign->id, 'format' => $format, 'variant' => $variant]);
            return;
        }

        // Cache-bust: the file path is stable across regenerations, so version the
        // URL by mtime — otherwise the app/store serve the old cached image.
        $v = '?v=' . (is_file($png) ? filemtime($png) : time());
        $url = Storage::disk('public')->url($relative);
        $creative->update([
            'status' => 'ready',
            'final_url' => $url . $v,
            'thumb_url' => $url . $v,
            'base_image_url' => $base ? Storage::disk('public')->url($this->relativeOf($base)) : null,
            'error' => null,
        ]);
    }

    /** Daily cost guard: beyond the cap, fall back to the placeholder driver. */
    private function resolveDriver(): string
    {
        $configured = (string) config('services.creative.driver', 'placeholder');
        if (! in_array($configured, ['replicate', 'gpt-image'], true)) {
            return $configured;
        }
        $cap = (int) config('services.creative.max_generations_per_day', 60);
        $today = CampaignCreative::whereDate('created_at', now()->toDateString())
            ->whereIn('driver', ['replicate', 'gpt-image'])->count();
        if ($today >= $cap) {
            Log::warning('[creative] daily generation cap reached — using placeholder', ['cap' => $cap]);
            return 'placeholder';
        }
        return $configured;
    }

    /**
     * Visual-only scene prompt. With a real product (nano-banana) we instruct it
     * to keep the product on the left and leave clean space on the right for the
     * Arabic text; without one (Imagen) we build a product-free scene.
     */
    private function scenePrompt(MarketingCampaign $campaign, bool $hasProduct, array $kit = []): string
    {
        $style = ! empty($kit['scene_style']) ? (', ' . $kit['scene_style']) : '';
        $imagery = $this->imageryDirection($kit['imagery_style'] ?? 'photographic');
        if ($hasProduct) {
            return 'Place the given product(s), packaging completely unchanged and fully visible, '
                . 'on the LEFT third of the frame. Premium e-commerce advertising scene' . $style
                . '. ' . $imagery . ' Keep the RIGHT two-thirds as clean, calm, empty space for text. '
                . 'No added text, no added logos, products identical to the references.';
        }
        $brief = $campaign->brief ?? [];
        if (! empty($brief['visual_prompt'])) {
            return (string) $brief['visual_prompt'] . $style . '. ' . $imagery . ' No text, no words.';
        }
        return 'premium e-commerce banner background for a pet & home goods store' . $style
            . ', clean empty area for text on the right, modern minimal, high quality. ' . $imagery . ' No text, no words.';
    }

    /** Turn a brand kit's imagery_style into an explicit art-direction clause. */
    private function imageryDirection(string $imageryStyle): string
    {
        return match ($imageryStyle) {
            'illustration' => 'Use a clean, modern flat illustration / graphic style — NO photorealism, no real animals.',
            'hybrid' => 'Combine the real product photograph with subtle illustrated brand motifs and graphic accents.',
            default => 'Use REAL professional product photography — no cartoon, no illustration. '
                . 'Real subjects, soft natural studio lighting, subtle reflection, cozy blurred background.',
        };
    }

    private function contentHash(MarketingCampaign $campaign, string $variant, array $productImages, array $kit = []): string
    {
        return sha1(json_encode([
            $campaign->headline_ar, $campaign->subheadline_ar, $campaign->cta_ar, $campaign->badge_ar,
            $campaign->scope, $campaign->discount_pct, $campaign->coupon_code,
            $this->scenePrompt($campaign, ! empty($productImages), $kit), $productImages, $variant,
            // brand-kit fields that change the rendered look → re-render when they change
            $kit['accent'] ?? null, $kit['accent_dark'] ?? null, $kit['gold'] ?? null,
            $kit['headline_font'] ?? null, $kit['body_font'] ?? null,
            $kit['imagery_style'] ?? null, $kit['logo_image'] ?? null,
            (string) config('services.creative.driver'),
            (string) config('services.replicate.scene_model'),
            (string) config('services.replicate.txt2img_model'),
        ]));
    }

    /** Real product image URLs for the campaign item + bundle companions. */
    private function productImages(MarketingCampaign $campaign): array
    {
        $codes = array_filter(array_merge([$campaign->item_code], $campaign->companion_item_codes ?? []));

        // Brand boutique campaign (no single product) → a few representative brand
        // products to stage as premium props in the brand-world scene.
        if (empty($codes) && ! empty($campaign->brand_code)) {
            return $this->brandProductImages((string) $campaign->brand_code);
        }

        $urls = [];
        foreach ($codes as $code) {
            $url = $this->firstImageUrl($code);
            if ($url) {
                $urls[] = $url;
            }
        }
        return $urls;
    }

    /** A few representative product images for a brand (props for the brand-world scene). */
    private function brandProductImages(string $brandCode, int $limit = 4): array
    {
        $codes = Product::where('items_group_code', $brandCode)
            ->whereNotNull('zb_images')
            ->orderByDesc('woo_sync') // prefer products that are live on the store
            ->limit(40)
            ->pluck('item_code')
            ->all();

        $urls = [];
        foreach ($codes as $code) {
            $url = $this->firstImageUrl($code);
            if ($url) {
                $urls[] = $url;
            }
            if (count($urls) >= $limit) {
                break;
            }
        }
        return $urls;
    }

    private function firstImageUrl(?string $itemCode): ?string
    {
        if (! $itemCode) {
            return null;
        }
        $images = Product::where('item_code', $itemCode)->value('zb_images');
        if (is_string($images)) {
            $images = json_decode($images, true);
        }
        if (is_array($images) && ! empty($images)) {
            $first = $images[0];
            return is_array($first) ? ($first['src'] ?? $first['url'] ?? null) : (is_string($first) ? $first : null);
        }
        return null;
    }

    /** Convert an absolute public-disk path to its disk-relative path. */
    private function relativeOf(string $absolute): string
    {
        $root = rtrim(Storage::disk('public')->path(''), '/');
        return ltrim(str_replace($root, '', $absolute), '/');
    }
}
