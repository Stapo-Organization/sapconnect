<?php

namespace App\Services\Marketing;

use App\Models\Product;
use App\Models\ProductBundle;
use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * The artwork behind the app's home slider.
 *
 * It was generated scenes for one afternoon — a rendered doorstep, a rendered
 * warehouse — and the owner's verdict was immediate: that is somebody else's
 * shop. What he had already approved is the bundle card, which is the
 * catalogue's own packshots composed with some craft. So this composes the
 * REAL product photos: the same products the slide is about, arranged per
 * subject by HeroCollageComposer, deterministic and free.
 *
 * No text is drawn into the art. The app writes its own Arabic over it, which
 * is the only way a slide can say «يوصلك الساعة 10:45 م» and still be true a
 * minute later.
 *
 * The output is a manifest the store reads (see Zooboxi_V2_Catalog_Controller);
 * nothing here talks to the app directly, and if the manifest is missing the
 * slider simply draws itself the way it did before.
 */
class HeroArtGenerator
{
    /** Kept for the store's contract: the app still asks "does this carry copy?" */
    public const MODE_SCENE = 'scene';

    /** Where the store looks for what we made. */
    public const MANIFEST = 'hero-art/manifest.json';

    /** How many product photos each arrangement wants. */
    public static function recipes(): array
    {
        return [
            'express_clock' => ['photos' => 3],
            'express_top' => ['photos' => 4],
            'express_new' => ['photos' => 3],
            'cutoff' => ['photos' => 3],
            'bundles' => ['photos' => 3],
            'clearance' => ['photos' => 3],
        ];
    }

    public function __construct(private HeroCollageComposer $collage, private BundleCardComposer $bundles)
    {
    }

    /**
     * Generate the art for [$themes] (all of them when empty) and rewrite the
     * manifest. Returns theme => public URL for what was made this run.
     *
     * @param array<int,string> $themes
     * @return array<string,string>
     */
    public function run(array $themes = [], ?callable $report = null): array
    {
        $recipes = self::recipes();
        if ($themes !== []) {
            $recipes = array_intersect_key($recipes, array_flip($themes));
        }

        $products = $this->productShots();
        $made = [];

        foreach ($recipes as $theme => $recipe) {
            $shots = array_slice(
                $products[$theme] ?? $products['_any'] ?? [],
                0,
                (int) ($recipe['photos'] ?? 3)
            );
            if ($shots === []) {
                $report && $report("skip {$theme} — no product photography to compose");
                continue;
            }

            // The app composes the slide itself; what it cannot do at runtime
            // is cut a packshot off its white studio card. Half the catalogue
            // is shot that way, and on a deep field those became small white
            // boxes with a product marooned inside — which is exactly what the
            // owner was looking at when he said it looked bad.
            $cutouts = [];
            foreach ($shots as $i => $url) {
                $name = "hero-art/cut/{$theme}-{$i}.png";
                if ($this->collage->cutout($url, Storage::disk('public')->path($name))) {
                    $cutouts[] = Storage::disk('public')->url($name);
                }
            }
            if ($cutouts === []) {
                $report && $report("skip {$theme} — nothing could be cut out");
                continue;
            }

            $made[$theme] = ['products' => $cutouts];
            $report && $report("cut {$theme} → " . count($cutouts) . ' product(s)');
        }

        $this->writeManifest($made);

        return $made;
    }

    /**
     * The need tiles' floating products.
     *
     * For every species' needs, up to three of the most wanted products cut
     * off their white cards and trimmed — «من كل فئة منتجين أو ثلاثة حسب
     * الأفضل بصريًا». Two when only two cut cleanly, none when none do; the
     * app then shows the tile's photo, and failing that its glyph. The best
     * seller leads, because it is the one the tile is really about.
     *
     * @return array<string,array<string,array{products:array<int,string>,version:string}>> species → need → products
     */
    public function needs(?callable $report = null): array
    {
        $home = $this->home('express');
        $stamp = (string) time();
        $made = [];

        foreach ((array) ($home['need_nav'] ?? []) as $species => $tiles) {
            foreach ((array) $tiles as $tile) {
                $key = (string) ($tile['key'] ?? '');
                $images = array_values(array_filter(array_map('strval', (array) ($tile['images'] ?? []))));
                if ($key === '' || $images === []) {
                    continue;
                }

                $cut = [];
                foreach ($images as $url) {
                    if (count($cut) >= 3) {
                        break;
                    }
                    $name = "hero-art/cut/need-{$species}-{$key}-" . count($cut) . '.png';
                    if ($this->collage->cutoutTrimmed($url, Storage::disk('public')->path($name)) !== null) {
                        // The name is stable so a phone can cache it; the stamp
                        // makes it ask again once the picture has changed.
                        $cut[] = Storage::disk('public')->url($name) . '?v=' . $stamp;
                    }
                }

                $report && $report("needs {$species}/{$key} → " . count($cut) . ' cut');
                if ($cut !== []) {
                    $made[(string) $species][$key] = ['products' => $cut, 'version' => $stamp];
                }
            }
        }

        $this->mergeManifest(['needs' => $made]);

        return $made;
    }

    /**
     * The home's own products, cut and trimmed, keyed by the photo the store
     * serves for them — so any card on the express home (the podium's top
     * three first of all) can float instead of sitting on its white card.
     *
     * Six per rail from the express home, deduplicated; the store looks a
     * card's `image` up in this map and hands the app a `cutout` beside it.
     *
     * @return array<string,string> source photo → cut-out
     */
    public function products(?callable $report = null): array
    {
        $home = $this->home('express');
        $stamp = (string) time();
        $cuts = [];
        $seen = [];

        foreach ((array) ($home['rails'] ?? []) as $rail) {
            $key = (string) ($rail['key'] ?? '');
            // Every product on the rail, not the first few: the app dedupes
            // each rail against the slots above it, so the podium's top three
            // or the wall's first row can come from anywhere in the twelve.
            foreach ((array) ($rail['products'] ?? []) as $card) {
                $src = (string) ($card['image'] ?? '');
                if ($src === '' || isset($seen[$src])) {
                    continue;
                }
                $seen[$src] = true;

                // A bundle's card is composed art on a painted ground; no
                // knock-out cuts it cleanly. The composer renders it again
                // with nothing behind the products instead.
                if (preg_match('/bundle-(\d+)/', $src, $m)) {
                    $bundle = ProductBundle::find((int) $m[1]);
                    $url = $bundle ? $this->bundles->renderCutout($bundle) : null;
                    if ($url !== null) {
                        $cuts[$src] = $url;
                    }
                    continue;
                }

                $name = 'hero-art/cut/p-' . md5($src) . '.png';
                if ($this->collage->cutoutTrimmed($src, Storage::disk('public')->path($name)) !== null) {
                    $cuts[$src] = Storage::disk('public')->url($name) . '?v=' . $stamp;
                }
            }
            $report && $report("products {$key} → " . count(array_intersect_key($cuts, $seen)) . ' cut so far');
        }

        // Laid over what earlier runs cut: a product that has left the rails
        // keeps its cut-out until the next full sweep replaces the map.
        $existing = (array) ($this->manifest()['cuts'] ?? []);
        $merged = $cuts + $existing;
        $this->mergeManifest(['cuts' => $merged]);
        $report && $report('cuts: ' . count($cuts) . ' fresh, ' . count($merged) . ' in the manifest');

        return $merged;
    }

    /**
     * Every product stocked on any express shelf, cut and trimmed, keyed by
     * its SAP code. The rails rotate hourly and a cut keyed by a card's image
     * only ever covered the products of one moment; keyed by code, whatever
     * the store puts on a rail tonight already has its cut-out waiting.
     *
     * Incremental: the file name carries a hash of the source photo, so an
     * unchanged product costs nothing on the second night and a re-shot one
     * is cut again. A few thousand products the first time, minutes after.
     *
     * @return array<string,string> item code => url
     */
    public function catalog(?callable $report = null): array
    {
        $shelves = ZooboxiWarehouse::active()->where('express_radius_km', '>', 0)->pluck('warehouse_code');
        $codes = WarehouseItemStock::whereIn('warehouse_code', $shelves)
            ->where('in_stock', '>', 0)
            ->distinct()
            ->pluck('item_code');

        $stamp = (string) time();
        $existing = (array) ($this->manifest()['codes'] ?? []);
        $out = [];
        $fresh = 0;
        $failed = 0;
        $done = 0;

        foreach ($codes->chunk(200) as $chunk) {
            $products = Product::whereIn('item_code', $chunk)->get(['item_code', 'zb_images']);
            foreach ($products as $product) {
                $code = (string) $product->item_code;
                $src = $this->photoOf($product);
                if ($src === null) {
                    continue;
                }
                $name = 'hero-art/cut/i-' . $code . '-' . substr(md5($src), 0, 8) . '.png';
                $disk = Storage::disk('public');
                if ($disk->exists($name)) {
                    $out[$code] = $existing[$code] ?? ($disk->url($name) . '?v=' . $stamp);
                } elseif ($this->collage->cutoutTrimmed($src, $disk->path($name)) !== null) {
                    $out[$code] = $disk->url($name) . '?v=' . $stamp;
                    $fresh++;
                } else {
                    $failed++;
                }
            }
            $done += $chunk->count();
            $report && $report("catalog {$done}/{$codes->count()} → " . count($out) . " cut, {$fresh} fresh, {$failed} refused");
        }

        // A product that left every shelf keeps its cut until the next full
        // sweep; nothing here is worth losing over a stock blip.
        $merged = $out + $existing;
        $this->mergeManifest(['codes' => $merged]);
        $report && $report('codes: ' . count($out) . ' on the shelves, ' . count($merged) . ' in the manifest');

        return $merged;
    }

    /** The product's first catalog photo: the store's, else the gallery host. */
    private function photoOf(Product $product): ?string
    {
        $imgs = $product->zb_images;
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
        $code = (string) $product->item_code;

        return $code !== '' ? "https://gal.holeno.com/imghd/{$code}.png" : null;
    }

    /**
     * Rewrite the manifest from the images already on disk — no generation, no
     * cost. For when the manifest gains a field (a tint, say) and the artwork
     * itself is still good.
     *
     * @return array<string,string> theme => url
     */
    public function refreshManifest(?callable $report = null): array
    {
        $made = [];
        foreach (array_keys(self::recipes()) as $theme) {
            $target = "hero-art/{$theme}.png";
            if (!Storage::disk('public')->exists($target)) {
                continue;
            }
            $made[$theme] = ['products' => []];
            $report && $report("{$theme} → re-listed");
        }
        $this->writeManifest($made);

        return array_map(fn ($row) => $row['url'], $made);
    }

    /**
     * The manifest the store reads: every theme we hold art for, its mode, and
     * a stamp that changes whenever a picture does — so a phone that cached the
     * old one asks again.
     *
     * @param array<string,array{url:string,tint:?string}> $made
     */
    private function writeManifest(array $made): void
    {
        $existing = $this->manifest()['art'] ?? [];

        foreach ($made as $theme => $row) {
            $existing[$theme] = [
                // No banner: the app draws the slide. What it gets from here
                // is the PRODUCTS, cut off their white cards, so they can float
                // on the field instead of sitting in little white boxes.
                'products' => $row['products'],
                'version' => (string) time(),
            ];
        }

        $this->mergeManifest(['art' => $existing]);
    }

    /** @return array<string,mixed> the manifest on disk, or nothing */
    private function manifest(): array
    {
        if (! Storage::disk('public')->exists(self::MANIFEST)) {
            return [];
        }
        $decoded = json_decode((string) Storage::disk('public')->get(self::MANIFEST), true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * Write the manifest with [$patch] laid over what is already there, so the
     * slides' run never drops the needs and the needs' run never drops the
     * slides.
     *
     * @param array<string,mixed> $patch
     */
    private function mergeManifest(array $patch): void
    {
        $current = $this->manifest();
        $out = [
            'generated_at' => now()->toIso8601String(),
            'art' => is_array($current['art'] ?? null) ? $current['art'] : [],
            'needs' => is_array($current['needs'] ?? null) ? $current['needs'] : [],
            'cuts' => is_array($current['cuts'] ?? null) ? $current['cuts'] : [],
            'codes' => is_array($current['codes'] ?? null) ? $current['codes'] : [],
        ];
        foreach ($patch as $key => $value) {
            $out[$key] = $value;
        }

        Storage::disk('public')->put(self::MANIFEST, (string) json_encode(
            $out,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
        ));
    }


    /**
     * The colour of the composition's CALM side, as `#rrggbb`.
     *
     * Every arrangement keeps its quiet half on the reading side, which is
     * where the app's own chrome sits, so that strip is the honest answer to
     * "what colour is this picture". Averaged over a coarse grid and pulled a
     * little darker, because white type and white icons live on top of it.
     */
    private function calmTint(string $path): ?string
    {
        if (!function_exists('imagecreatefrompng')) {
            return null;
        }

        $img = @imagecreatefrompng($path);
        if ($img === false) {
            return null;
        }

        $w = imagesx($img);
        $h = imagesy($img);
        [$r, $g, $b, $n] = [0, 0, 0, 0];
        for ($x = (int) ($w * 0.70); $x < $w; $x += max(1, (int) ($w * 0.025))) {
            for ($y = 0; $y < $h; $y += max(1, (int) ($h * 0.08))) {
                $rgb = imagecolorat($img, $x, $y);
                $r += ($rgb >> 16) & 0xFF;
                $g += ($rgb >> 8) & 0xFF;
                $b += $rgb & 0xFF;
                $n++;
            }
        }
        imagedestroy($img);

        if ($n === 0) {
            return null;
        }

        // 0.86: a shade under the picture, so the seam between the canvas and
        // the art reads as depth rather than as a mismatch.
        return sprintf(
            '#%02x%02x%02x',
            (int) min(255, ($r / $n) * 0.86),
            (int) min(255, ($g / $n) * 0.86),
            (int) min(255, ($b / $n) * 0.86)
        );
    }

    /**
     * The photography to compose with — each slide gets the goods it is
     * ACTUALLY about.
     *
     * The store already sorts the catalogue into the rails the slides refer
     * to, so «الأكثر طلباً» composes the bestsellers, «وصل حديثاً» composes
     * what is new, «التصفية» composes what is discounted, and «البكجات»
     * composes the bundle artwork itself. Composing all six from one pool gave
     * six slides of the same tin; composing them from the wrong pool would be
     * worse — a slide about the clearance shelf showing full-price stock.
     *
     * @return array<string,array<int,string>>
     */
    private function productShots(): array
    {
        $rails = [];
        $heroOwn = [];
        foreach (['express', 'all'] as $shelf) {
            $home = $this->home($shelf);

            foreach ((array) ($home['rails'] ?? []) as $rail) {
                $key = (string) ($rail['key'] ?? '');
                foreach ((array) ($rail['products'] ?? []) as $card) {
                    $img = (string) ($card['image'] ?? '');
                    // Bundle artwork is a composed card, not a packshot; it
                    // belongs to «البكجات» and nowhere else.
                    if ($key === '' || $img === '' || str_contains($img, 'bundle-')) {
                        continue;
                    }
                    $rails[$key][] = $img;
                }
            }
            foreach ((array) ($home['hero'] ?? []) as $slide) {
                $theme = (string) ($slide['theme'] ?? '');
                $images = array_values(array_filter((array) ($slide['product_images'] ?? [])));
                if ($theme !== '' && $images !== [] && !isset($heroOwn[$theme])) {
                    $heroOwn[$theme] = $images;
                }
            }
        }

        $rails = array_map(fn ($list) => array_values(array_unique($list)), $rails);
        $everything = array_values(array_unique(array_merge(...array_values($rails) ?: [[]])));

        // Which shelf each subject is about. `offset` keeps two slides drawn
        // from the same rail from showing the same three tins.
        $sources = [
            'express_clock' => ['trending', 0],
            'express_top' => ['bestsellers', 0],
            'express_new' => ['new', 0],
            'cutoff' => ['trending', 4],
            'bundles' => ['__own', 0],
            'clearance' => ['clearance', 0],
        ];

        $out = ['_any' => $everything];
        foreach ($sources as $theme => [$railKey, $offset]) {
            if ($railKey === '__own' && !empty($heroOwn[$theme])) {
                $out[$theme] = $heroOwn[$theme];
                continue;
            }

            $pool = $rails[$railKey] ?? [];
            if (count($pool) < 3) {
                $pool = $everything;
            }
            if ($pool === []) {
                continue;
            }

            $slice = [];
            for ($n = 0; $n < 4; $n++) {
                $slice[] = $pool[($offset + $n) % count($pool)];
            }
            $out[$theme] = $slice;
        }

        return $out;
    }

    /** @return array<string,mixed> the store's own /home payload */
    private function home(string $shelf): array
    {
        $base = rtrim((string) config('services.woo.store_url', 'https://store.zooboxi.com'), '/');
        try {
            $resp = Http::timeout(30)
                ->withHeaders([
                    'X-ZB-Shelf' => $shelf,
                    // Riyadh: the art is national, but the endpoint needs a
                    // point to resolve a shelf at all.
                    'X-ZB-Lat' => '24.7136',
                    'X-ZB-Lng' => '46.6753',
                    'X-ZB-City' => rawurlencode('الرياض'),
                ])
                ->get("{$base}/wp-json/zooboxi/v2/home");

            return $resp->successful() ? (array) ($resp->json('data') ?? []) : [];
        } catch (\Throwable $e) {
            Log::warning('[hero-art] could not read the store hero: ' . $e->getMessage());
            return [];
        }
    }

}
