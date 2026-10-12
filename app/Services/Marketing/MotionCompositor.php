<?php

namespace App\Services\Marketing;

use App\Models\MarketingCampaign;
use App\Models\Product;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;

/**
 * Zero-cost creative engine (approved 2026-09-23): composes a campaign's ad from the one-time
 * character/sticker library + the real product cut-out + the brand layer, then exports THREE
 * artefacts from the same template — static PNG, animated SVG (store) and animated WebP (app).
 * No AI call per ad. Rendering is done by Node (resources/js/zooboxi-engine) with resvg.
 *
 * Inputs are resolved here: format from the placement, ad type from the campaign type, character
 * from the products' species, palette from the design identity (brand accent) or the product's
 * dominant colour, price block from the offer, copy from the owner-edited campaign fields.
 */
class MotionCompositor
{
    /** placement format → engine template. */
    private const FORMAT_MAP = ['hero' => 'hero', 'wide' => 'wide', 'strip' => 'strip', 'card' => 'card', 'feed' => 'feed', 'story' => 'story', 'app_hero' => 'app_hero', 'hero_wide' => 'hero_wide'];

    /** campaign_type → choreography / joy vocabulary. */
    private const AD_TYPE = ['clearance' => 'offer', 'spotlight' => 'hero', 'bundle' => 'offer', 'new_arrival' => 'party', 'express' => 'service'];

    /** species → character poses (seed picks one; only those present on disk are used). */
    private const CHARACTERS = [
        // Compact poses only (they sit beside the product without climbing into the text column);
        // running/jumping poses are reserved for the express strip (see render()).
        'cat' => ['cat-sit-up', 'cat-present', 'cat-wave', 'cat-peek', 'cat-point', 'cat-thumbs', 'cat-wow', 'cat-celebrate'],
        'dog' => ['dog-present', 'dog-wave', 'dog-sit-up', 'dog-peek', 'dog-point', 'dog-wow', 'dog-celebrate'],
        'bird' => ['budgie'],
        'small_pet' => ['hamster', 'rabbit'],
        'fish' => ['fish'],
        'mixed' => ['cat-present', 'dog-present', 'cat-wave', 'dog-wave'],
    ];

    /** Slots the app plays as animated WebP; every other slot animates as inline SVG in the store. */
    private const ANIMATED_FORMATS = ['app_hero', 'wide', 'strip', 'card'];

    /** Party / offer stickers (generated once, storage creatives/bases/pop). */
    private const POP = ['sparkle-burst', 'star-glossy', 'hearts-cluster', 'stars-cluster', 'confetti-burst', 'heart-glossy'];

    public function __construct(private CampaignOfferGuard $guard) {}

    /**
     * Render one format for a campaign variant.
     *
     * @return array{png:string,svg:?string,webp:?string,meta:array}|null absolute paths on the public disk
     */
    public function render(MarketingCampaign $campaign, string $format, string $variant, array $kit, bool $staticOnly = false): ?array
    {
        $template = self::FORMAT_MAP[$format] ?? 'hero';
        $seed = ($campaign->id * 7 + ($variant === 'B' ? 101 : 0)) % 9973 + 1;

        $products = $this->productAssets($campaign);
        $species = $this->species($campaign, $kit);
        $character = $this->pickCharacter($species, $seed + ($variant === 'B' ? 3 : 0));
        if (in_array($template, ['strip', 'wide'], true) && in_array($species, ['cat', 'dog'], true) && $campaign->campaign_type === 'express'
            && is_file(Storage::disk('public')->path("creatives/bases/chars/{$species}-run.png"))) {
            $character = "{$species}-run"; // the express strip is the one place a running pet belongs
        }

        $spec = [
            'format' => $template,
            'ad_type' => self::AD_TYPE[$campaign->campaign_type] ?? 'offer',
            'seed' => $seed,
            'copy' => $this->copy($campaign),
            'price' => $this->price($campaign),
            'products' => $products,
            'character' => $character,
            'pop_names' => self::POP,
            'colors' => $this->colors($campaign, $kit),
            'assets' => [
                'chars_dir' => Storage::disk('public')->path('creatives/bases/chars'),
                'pop_dir' => Storage::disk('public')->path('creatives/bases/pop'),
                'logo' => Storage::disk('public')->path('creatives/bases/logo.png'),
                'cache' => Storage::disk('local')->path('creative-cache/assets.json'),
                'font_dir' => base_path('resources/fonts/zooboxi'),
            ],
            'asset_urls' => $this->assetUrls($products, $character),
            'out' => [
                'dir' => Storage::disk('public')->path("creatives/{$campaign->id}"),
                'name' => "{$format}-{$variant}",
                'frames' => (int) config('services.creative.motion_frames', 72),
                'app_w' => (int) config('services.creative.motion_app_width', 1080),
                'play_ms' => (int) config('services.creative.motion_play_ms', 3000),
                'quality' => (int) config('services.creative.motion_webp_quality', 80),
                'webp_tool' => (string) config('services.creative.motion_webp_tool', 'auto'),
                // Only the slots the app animates are encoded as WebP; the store gets the SVG.
                'webp' => in_array($template, self::ANIMATED_FORMATS, true),
                'static_only' => $staticOnly,
            ],
        ];

        Storage::disk('local')->makeDirectory('creative-cache');
        Storage::disk('public')->makeDirectory("creatives/{$campaign->id}");
        $specPath = Storage::disk('local')->path("creative-cache/spec-{$campaign->id}-{$format}-{$variant}" . ($staticOnly ? '-static' : '') . '.json');
        file_put_contents($specPath, json_encode($spec, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT));

        $node = (string) config('services.creative.node_binary', 'node');
        $script = base_path('resources/js/zooboxi-engine/render.mjs');
        $result = Process::timeout((int) config('services.creative.motion_timeout', 240))->path(base_path())->run([$node, $script, $specPath]);

        $line = trim((string) collect(explode("\n", trim($result->output())))->last());
        $meta = json_decode($line, true);
        if (! $result->successful() || ! is_array($meta) || empty($meta['ok']) || ! is_file($meta['png'] ?? '')) {
            Log::error('[creative] motion engine failed', ['campaign' => $campaign->id, 'format' => $format, 'exit' => $result->exitCode(), 'err' => mb_substr($result->errorOutput(), 0, 2000), 'out' => mb_substr($result->output(), 0, 500)]);
            return null;
        }

        return [
            'png' => $meta['png'],
            'svg' => is_file($meta['svg'] ?? '') ? $meta['svg'] : null,
            'webp' => is_file((string) ($meta['webp'] ?? '')) ? $meta['webp'] : null,
            'meta' => ['engine' => 'motion', 'template' => $template, 'ad_type' => $spec['ad_type'], 'seed' => $seed, 'character' => $character, 'species' => $species, 'frames' => $meta['frames'] ?? null, 'app_w' => $meta['app_w'] ?? null, 'fps' => $meta['fps'] ?? null, 'webp_kb' => $meta['webp_kb'] ?? null, 'svg_kb' => $meta['svg_kb'] ?? null, 'tool' => $meta['tool'] ?? null],
        ];
    }

    /** Content hash: everything that changes the rendered output. */
    public function hash(MarketingCampaign $campaign, string $variant, array $kit): string
    {
        return sha1(json_encode([
            self::ENGINE_VERSION, $campaign->campaign_type, $campaign->placement, $campaign->design_identity,
            $campaign->headline_ar, $campaign->subheadline_ar, $campaign->cta_ar, $campaign->badge_ar,
            $campaign->discount_pct, $campaign->base_price, $campaign->item_code, $campaign->companion_item_codes,
            $kit['accent'] ?? null, $kit['brand_name'] ?? null, $variant,
            config('services.creative.motion_frames'), config('services.creative.motion_app_width'),
        ]));
    }

    // ------------------------------------------------------------------ spec parts

    /** Marketing headline per campaign type (used when the campaign headline is really a product name). */
    private const TYPE_HEADLINE = ['spotlight' => 'الأكثر طلباً', 'clearance' => 'عرض خاص', 'new_arrival' => 'وصل حديثاً', 'express' => 'يوصلك خلال ساعتين', 'bundle' => 'اشترِ معاً ووفّر'];

    private function productName(MarketingCampaign $c): string
    {
        if (! $c->item_code) {
            return '';
        }
        $p = Product::where('item_code', $c->item_code)->first();
        return trim((string) ($p->zb_name_ar ?? $p->item_name_ar ?? $p->item_name ?? ''));
    }

    /** Catalogue name → short display name: sizes/packs/parentheses stripped, at most 4 words. */
    public function shortName(string $name): string
    {
        $n = preg_replace('/\([^)]*\)/u', ' ', $name);
        $n = preg_replace('/\b\d+([.,]\d+)?\s*(غ|جم|جرام|كجم|كغ|كيلو|مل|لتر|ل|حبة|حبات|قطعة|قطع|كيس|علبة|kg|g|gm|ml|l|pcs|pc|x)\b/iu', ' ', $n);
        $n = preg_replace('/(\d+\s*[×x]\s*\d+|[×x]\s*\d+|\d+\s*[×x])/iu', ' ', $n);
        $n = preg_replace('/[\-–—·|,]+/u', ' ', $n);
        $n = trim(preg_replace('/\s+/u', ' ', $n));
        $words = array_values(array_filter(explode(' ', $n), fn ($w) => $w !== '' && ! preg_match('/^\d+([.,]\d+)?$/', $w)));
        return implode(' ', array_slice($words, 0, 4));
    }

    /** Bump when the templates/engine change so approved campaigns re-render on the next run. */
    public const ENGINE_VERSION = 'motion-v6';

    /** Customer copy never names a branch; legacy suggestions glued the badge onto the product name. */
    private function sanitize(string $text, string $badge = ''): string
    {
        $text = trim($text);
        $text = str_replace(['متوفّر في فرعك · ', 'متوفّر الآن في فرعك', 'في فرعك', 'فرعك', 'الفرع'], ['', 'متوفّر الآن', 'الآن', 'إكسبريس', 'إكسبريس'], $text);
        foreach (['الأكثر طلباً', 'وصل حديثاً', 'عرض خاص', 'احصل عليه خلال ساعتين', $badge] as $prefix) {
            if ($prefix !== '' && str_starts_with($text, $prefix . ' — ')) {
                $text = trim(mb_substr($text, mb_strlen($prefix . ' — ')));
            }
        }
        return trim($text, " -—·");
    }

    private function copy(MarketingCampaign $c): array
    {
        $badge = trim((string) $c->badge_ar);
        // A short badge (≤ 8 chars, e.g. «جديد», «−30٪») sits in the round badge; longer ones become the kicker pill.
        $short = $badge !== '' && mb_strlen($badge) <= 8 && ! str_contains($badge, ' ');
        $trust = [['cash', 'الدفع عند الاستلام']];
        if ($c->target_express_only || $c->campaign_type === 'express') {
            array_unshift($trust, ['clock', 'توصيل خلال ساعتين']);
        }
        $extra = config('services.creative.trust_lines');
        if (is_array($extra) && $extra) {
            $trust = $extra;
        }

        // Headline policy: a product name is not a headline. When the headline is long or reads like a
        // catalogue name (sizes, packs), the type phrase becomes the headline and the SHORT product name
        // the support line; the owner's own short headline is always kept as written.
        $headline = $this->sanitize((string) $c->headline_ar, $badge);
        $sub = $this->sanitize((string) $c->subheadline_ar);
        $name = $this->shortName($this->productName($c));
        $looksLikeName = mb_strlen($headline) > 26 || preg_match('/\d\s*(غ|جم|كجم|كغ|مل|لتر|حبة|حبات|قطعة|×|x|kg|g|ml)/iu', $headline);
        if ($headline === '' || $looksLikeName) {
            $headline = self::TYPE_HEADLINE[$c->campaign_type] ?? 'عرض زوبوكسي';
            $sub = $name !== '' ? $name : $sub;
        } elseif ($sub === '' && $name !== '') {
            $sub = $name;
        }
        if (mb_strlen($sub) > 34) {
            $sub = $this->shortName($sub);
        }

        // Never say the same words twice: a badge/kicker that equals the headline is dropped.
        if ($badge !== '' && mb_strtolower($badge) === mb_strtolower($headline)) {
            $badge = '';
            $short = false;
        }

        return [
            'kicker' => $short ? null : ($badge !== '' ? $badge : null),
            'headline' => $headline,
            'sub' => $sub !== '' ? $sub : null,
            'cta' => trim((string) $c->cta_ar) ?: 'اطلب الآن',
            'badge1' => $short && $badge !== '' ? $badge : null,
            'badge2' => null,
            'trust' => $trust,
        ];
    }

    /** Price block: coupon offers show new + struck old price; visibility campaigns show the retail price. */
    private function price(MarketingCampaign $c): ?array
    {
        if (! $c->item_code) {
            return null;
        }
        // A bundle has no single honest number unless it carries a coupon → no price block.
        if ($c->campaign_type === 'bundle' && ! ($c->scope === 'coupon' && (float) $c->discount_pct > 0)) {
            return null;
        }
        $line = $this->guard->lineFor((string) $c->item_code, $c->base_price ? (float) $c->base_price : null);
        $base = (float) ($line['base'] ?? 0);
        if ($base <= 0) {
            return null;
        }
        $fmt = fn (float $v) => rtrim(rtrim(number_format($v, 2, '.', ''), '0'), '.');
        if ($c->scope === 'coupon' && (float) $c->discount_pct > 0) {
            $new = $base * (1 - (float) $c->discount_pct / 100);
            return ['amount' => $fmt($new), 'label' => $c->coupon_code ? "بكود {$c->coupon_code}" : null, 'old' => $fmt($base)];
        }
        return ['amount' => $fmt($base), 'label' => null, 'old' => null];
    }

    /** Brand identity → brand accent palette; store identity → null (engine derives it from the product). */
    private function colors(MarketingCampaign $c, array $kit): ?array
    {
        $isBrandLook = $c->design_identity === 'brand' || (! empty($c->brand_code));
        if (! $isBrandLook || empty($kit['accent'])) {
            return null;
        }
        return ['c1' => $kit['accent'], 'c2' => $kit['accent_dark'] ?? null, 'accent' => $kit['gold'] ?? null];
    }

    /**
     * Product cut-outs cached on the public disk (creatives/bases/products/<code>.png) so the animated
     * SVG can reference them by URL. Non-PNG catalog images are converted with ImageMagick.
     *
     * @return array<int,array{name:string,file:string,count:int}>
     */
    private function productAssets(MarketingCampaign $c): array
    {
        $codes = array_values(array_filter(array_merge([$c->item_code], $c->companion_item_codes ?? [])));
        $out = [];
        foreach (array_slice($codes, 0, 3) as $code) {
            $p = Product::where('item_code', $code)->first();
            $file = $this->cachedProductPng((string) $code, $p);
            if (! $file) {
                continue;
            }
            $count = 1;
            if ($c->campaign_type === 'bundle' && count($codes) === 1) {
                $count = 2;
            }
            $out[] = ['name' => 'p-' . preg_replace('/[^A-Za-z0-9]/', '', (string) $code), 'file' => $file, 'count' => $count];
        }
        return $out;
    }

    private function cachedProductPng(string $code, ?Product $p): ?string
    {
        $rel = 'creatives/bases/products/' . preg_replace('/[^A-Za-z0-9]/', '', $code) . '.png';
        $abs = Storage::disk('public')->path($rel);
        if (is_file($abs) && filesize($abs) > 1024 && filemtime($abs) > time() - 30 * 86400) {
            return $abs;
        }
        Storage::disk('public')->makeDirectory('creatives/bases/products');

        $urls = [];
        $imgs = $p?->zb_images;
        if (is_string($imgs)) {
            $imgs = json_decode($imgs, true);
        }
        if (is_array($imgs)) {
            foreach ($imgs as $i) {
                $u = is_array($i) ? ($i['src'] ?? $i['url'] ?? null) : (is_string($i) ? $i : null);
                if ($u) {
                    $urls[] = $u;
                }
            }
        }
        $urls[] = "https://gal.holeno.com/imghd/{$code}.png";

        foreach ($urls as $u) {
            try {
                $r = Http::timeout(25)->get($u);
                if (! $r->successful() || strlen($r->body()) < 1024) {
                    continue;
                }
                $body = $r->body();
                $isPng = str_starts_with($body, "\x89PNG");
                if ($isPng) {
                    file_put_contents($abs, $body);
                    return $abs;
                }
                // jpg/webp → PNG (ImageMagick is present locally and on the server)
                $tmp = $abs . '.src';
                file_put_contents($tmp, $body);
                $conv = Process::timeout(60)->run(['convert', $tmp, 'PNG32:' . $abs]);
                @unlink($tmp);
                if ($conv->successful() && is_file($abs)) {
                    return $abs;
                }
            } catch (\Throwable $e) {
                Log::warning('[creative] product image fetch failed', ['code' => $code, 'url' => $u, 'err' => $e->getMessage()]);
            }
        }
        return null;
    }

    private function assetUrls(array $products, ?string $character): array
    {
        $disk = Storage::disk('public');
        $urls = ['logo' => $disk->url('creatives/bases/logo.png')];
        foreach (self::POP as $n) {
            $urls[$n] = $disk->url("creatives/bases/pop/{$n}.png");
        }
        if ($character) {
            $urls[$character] = $disk->url("creatives/bases/chars/{$character}.png");
        }
        foreach ($products as $p) {
            $urls[$p['name']] = $disk->url('creatives/bases/products/' . basename($p['file']));
        }
        return $urls;
    }

    private function pickCharacter(string $species, int $seed): ?string
    {
        $dir = Storage::disk('public')->path('creatives/bases/chars');
        $pool = array_values(array_filter(self::CHARACTERS[$species] ?? self::CHARACTERS['mixed'], fn ($n) => is_file("{$dir}/{$n}.png")));
        if (! $pool) {
            $pool = array_values(array_filter(self::CHARACTERS['mixed'], fn ($n) => is_file("{$dir}/{$n}.png")));
        }
        return $pool ? $pool[$seed % count($pool)] : null;
    }

    /** Species of the campaign's products (name keywords), falling back to the kit category. */
    private function species(MarketingCampaign $campaign, array $kit): string
    {
        $codes = array_filter(array_merge([$campaign->item_code], $campaign->companion_item_codes ?? []));
        if (empty($codes) && ! empty($campaign->brand_code)) {
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
                if (str_contains($hay, $k)) {
                    $found[] = $sp;
                    break;
                }
            }
        }
        if (count($found) === 1) {
            return $found[0];
        }
        if (count($found) > 1) {
            return 'mixed';
        }
        $cat = (string) ($kit['category'] ?? '');
        return isset(self::CHARACTERS[$cat]) ? $cat : 'mixed';
    }
}
