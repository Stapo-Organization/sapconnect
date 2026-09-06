<?php

namespace App\Services\Marketing;

use App\Models\Product;
use App\Models\ProductBundle;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;

/**
 * The bundle's product-card image — Mowkly's collage language in Zooboxi's
 * identity, composed deterministically from the REAL catalog photos (no AI,
 * no cost, same result every render):
 *
 *   stacking   — the product fanned into a stack + a coral «+N مجاناً» roundel
 *   variety    — the flavours side by side, each with its count
 *   companion / smart_gift — big anchor + the gift under a «مجاناً» roundel,
 *                joined by a hand-drawn coral plus
 *
 * Square 1000×1000 on a warm bone ground with a white stage (catalog shots
 * are white-background, so they blend seamlessly). Arabic set in Tajawal via
 * resvg (same render-banner.mjs pipeline as the ad engine).
 */
class BundleCardComposer
{
    private const W = 1000;
    private const H = 1000;

    private const TEAL = '#429D9C';
    private const TEAL_DEEP = '#2C6B6A';
    private const CORAL = '#D46856';
    private const BONE = '#F6F4EF';
    private const LINE = '#E4DFD2';
    private const INK = '#22312F';

    /** Render the card; returns the public URL (?v=mtime) or null. */
    public function render(ProductBundle $bundle): ?string
    {
        $bundle->loadMissing('items');

        $svg = $this->buildSvg($bundle);
        if ($svg === null) {
            return null;
        }

        $dir = storage_path('app/public/creatives/bundles');
        if (! is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
        $svgPath = $dir . "/bundle-{$bundle->id}.svg";
        $pngPath = $dir . "/bundle-{$bundle->id}.png";
        file_put_contents($svgPath, $svg);

        $node = (string) config('services.creative.node_binary', 'node');
        $script = base_path('resources/js/render-banner.mjs');
        $fontDir = resource_path('fonts/cairo');

        $result = Process::timeout(60)->run([$node, $script, $svgPath, $pngPath, $fontDir]);
        @unlink($svgPath);
        if (! $result->successful() || ! is_file($pngPath)) {
            return null;
        }

        return asset('storage/creatives/bundles/' . basename($pngPath)) . '?v=' . filemtime($pngPath);
    }

    /* ═══════════════════════════ composition ═══════════════════════════ */

    private function buildSvg(ProductBundle $bundle): ?string
    {
        $items = $bundle->items;
        $anchor = $items->firstWhere('role', 'anchor') ?? $items->first();
        if ($anchor === null) {
            return null;
        }

        $anchorImg = $this->imageDataUri($anchor->item_code);
        if ($anchorImg === null) {
            return null; // no photo, no card — the store falls back to the thumbnail rule
        }

        $stage = match ($bundle->template) {
            'stacking' => $this->stackingStage($bundle, $anchorImg),
            'variety' => $this->varietyStage($bundle),
            default => $this->giftStage($bundle, $anchorImg),
        };
        if ($stage === null) {
            return null;
        }

        $w = self::W;
        $h = self::H;
        $bone = self::BONE;
        $line = self::LINE;
        $tealDeep = self::TEAL_DEEP;
        $coral = self::CORAL;

        $footRight = $this->esc('حزم زوبوكسي');
        $footLeft = $this->esc($this->footLine($bundle));

        return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="{$w}" height="{$h}" viewBox="0 0 {$w} {$h}">
  <rect width="{$w}" height="{$h}" fill="{$bone}"/>
  <rect x="36" y="36" width="928" height="838" rx="40" fill="#FFFFFF" stroke="{$line}" stroke-width="2"/>
  {$stage}
  <g font-family="Tajawal">
    <text x="956" y="946" text-anchor="end" font-size="38" font-weight="700" fill="{$tealDeep}">{$footRight}</text>
    <circle cx="906" cy="933" r="7" fill="{$coral}"/>
    <text x="44" y="946" text-anchor="start" font-size="40" font-weight="700" fill="{$coral}">{$footLeft}</text>
  </g>
</svg>
SVG;
    }

    /** The product fanned into a stack, the free count on a coral roundel. */
    private function stackingStage(ProductBundle $bundle, string $img): string
    {
        [, $free] = $this->ladderOf($bundle);
        $roundel = $this->roundel(190, 200, $free > 0 ? "+{$free}" : '', 'مجاناً');
        $caption = $this->esc($this->countLine($bundle));
        $ink = self::INK;

        return <<<SVG
  <g>
    <image href="{$img}" x="200" y="180" width="440" height="440" transform="rotate(-8 420 400)" opacity="0.92"/>
    <image href="{$img}" x="360" y="180" width="440" height="440" transform="rotate(8 580 400)" opacity="0.96"/>
    <image href="{$img}" x="280" y="220" width="460" height="460"/>
  </g>
  {$roundel}
  <text x="500" y="790" text-anchor="middle" font-family="Tajawal" font-size="40" font-weight="700" fill="{$ink}">{$caption}</text>
SVG;
    }

    /** The flavours side by side, each with its count. */
    private function varietyStage(ProductBundle $bundle): ?string
    {
        $members = $bundle->items->take(5)->values();
        $images = [];
        foreach ($members as $m) {
            $uri = $this->imageDataUri($m->item_code);
            if ($uri !== null) {
                $images[] = ['img' => $uri, 'qty' => (int) $m->qty];
            }
        }
        if (count($images) < 2) {
            return null;
        }

        $n = count($images);
        $cell = (int) min(280, floor(880 / $n));
        $totalW = $cell * $n;
        $x0 = (int) ((self::W - $totalW) / 2);
        $y = (int) (430 - $cell / 2);
        $teal = self::TEAL_DEEP;

        $out = '';
        foreach ($images as $i => $entry) {
            $x = $x0 + $i * $cell;
            $imgW = $cell - 16;
            $qty = $entry['qty'];
            $tx = $x + (int) ($cell / 2);
            $ty = $y + $cell + 44;
            $out .= <<<SVG
  <image href="{$entry['img']}" x="{$x}" y="{$y}" width="{$imgW}" height="{$imgW}"/>
  <text x="{$tx}" y="{$ty}" text-anchor="middle" font-family="Tajawal" font-size="36" font-weight="700" fill="{$teal}">×{$qty}</text>
SVG;
        }

        [, $free] = $this->ladderOf($bundle);
        $out .= $this->roundel(180, 190, $free > 0 ? "+{$free}" : '', 'مجاناً');
        $caption = $this->esc($this->countLine($bundle));
        $ink = self::INK;
        $out .= "\n  <text x=\"500\" y=\"790\" text-anchor=\"middle\" font-family=\"Tajawal\" font-size=\"40\" font-weight=\"700\" fill=\"{$ink}\">{$caption}</text>";

        return $out;
    }

    /** Big anchor + the gift under a «مجاناً» roundel, joined by a coral plus. */
    private function giftStage(ProductBundle $bundle, string $anchorImg): ?string
    {
        $gift = $bundle->items->firstWhere('role', 'gift');
        $giftImg = $gift ? $this->imageDataUri($gift->item_code) : null;
        $coral = self::CORAL;
        $teal = self::TEAL_DEEP;

        // Anchor alone (gift photo missing): centre it and keep the roundel.
        if ($gift === null || $giftImg === null) {
            $roundel = $this->roundel(190, 200, '', 'مجاناً');
            return "\n  <image href=\"{$anchorImg}\" x=\"250\" y=\"180\" width=\"500\" height=\"560\" preserveAspectRatio=\"xMidYMid meet\"/>{$roundel}";
        }

        $qty = (int) $gift->qty;
        $qtyLabel = $qty > 1 ? "×{$qty}" : '';
        $roundel = $this->roundel(215, 205, '', 'مجاناً');

        return <<<SVG
  <image href="{$anchorImg}" x="440" y="170" width="480" height="580" preserveAspectRatio="xMidYMid meet"/>
  <image href="{$giftImg}" x="95" y="320" width="300" height="330" preserveAspectRatio="xMidYMid meet"/>
  <text x="245" y="720" text-anchor="middle" font-family="Tajawal" font-size="40" font-weight="700" fill="{$teal}">{$qtyLabel}</text>
  {$roundel}
  <g transform="rotate(-6 415 470)">
    <rect x="385" y="458" width="64" height="22" rx="11" fill="{$coral}"/>
    <rect x="406" y="437" width="22" height="64" rx="11" fill="{$coral}"/>
  </g>
SVG;
    }

    /** The tilted coral «مجاناً» badge every Mowkly bundle leads with. */
    private function roundel(int $cx, int $cy, string $top, string $word): string
    {
        $coral = self::CORAL;
        $word = $this->esc($word);
        $topLine = $top !== ''
            ? "<text x=\"{$cx}\" y=\"" . ($cy - 8) . "\" text-anchor=\"middle\" font-family=\"Tajawal\" font-size=\"56\" font-weight=\"700\" fill=\"#FFFFFF\">{$this->esc($top)}</text>"
            : '';
        $wordY = $top !== '' ? $cy + 44 : $cy + 16;
        $wordSize = $top !== '' ? 38 : 44;

        return <<<SVG
  <g transform="rotate(-8 {$cx} {$cy})">
    <circle cx="{$cx}" cy="{$cy}" r="108" fill="{$coral}"/>
    <circle cx="{$cx}" cy="{$cy}" r="96" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" stroke-dasharray="2 10" stroke-linecap="round"/>
    {$topLine}
    <text x="{$cx}" y="{$wordY}" text-anchor="middle" font-family="Tajawal" font-size="{$wordSize}" font-weight="700" fill="#FFFFFF">{$word}</text>
  </g>
SVG;
    }

    /* ═══════════════════════════ words ═══════════════════════════ */

    /** "12+3" → [12, 3]; anything else → [0, 0]. */
    private function ladderOf(ProductBundle $bundle): array
    {
        if (preg_match('/^(\d+)\+(\d+)$/', (string) $bundle->free_label, $m)) {
            return [(int) $m[1], (int) $m[2]];
        }
        return [0, 0];
    }

    private function countLine(ProductBundle $bundle): string
    {
        [$paid, $free] = $this->ladderOf($bundle);
        if ($paid > 0) {
            $total = $paid + $free;
            return "الإجمالي {$total} قطعة — تدفع ثمن {$paid} فقط";
        }
        return $bundle->subtitle_ar ?? '';
    }

    private function footLine(ProductBundle $bundle): string
    {
        [$paid, $free] = $this->ladderOf($bundle);
        if ($paid > 0) {
            return "{$paid} + {$free} مجاناً";
        }
        $gift = $bundle->items->firstWhere('role', 'gift');
        if ($gift) {
            return $gift->qty > 1 ? "{$gift->qty} هدايا معه" : 'وهدية معه';
        }
        return '';
    }

    /* ═══════════════════════════ images ═══════════════════════════ */

    /** First catalog image of an item as a data URI (zb_images, else gal host). */
    private function imageDataUri(string $itemCode): ?string
    {
        $p = Product::where('item_code', $itemCode)->first();
        $urls = [];

        $imgs = $p?->zb_images;
        if (is_string($imgs)) {
            $imgs = json_decode($imgs, true);
        }
        if (is_array($imgs) && ! empty($imgs[0])) {
            $first = $imgs[0];
            $url = is_array($first) ? ($first['src'] ?? $first['url'] ?? null) : $first;
            if (is_string($url) && $url !== '') {
                $urls[] = $url;
            }
        }
        $urls[] = "https://gal.holeno.com/imghd/{$itemCode}.png";

        foreach ($urls as $url) {
            try {
                $resp = Http::timeout(15)->get($url);
                if ($resp->successful() && strlen($resp->body()) > 500) {
                    $ext = strtolower(pathinfo(parse_url($url, PHP_URL_PATH) ?: '', PATHINFO_EXTENSION));
                    $mime = $ext === 'png' ? 'image/png' : ($ext === 'webp' ? 'image/webp' : 'image/jpeg');
                    return 'data:' . $mime . ';base64,' . base64_encode($resp->body());
                }
            } catch (\Throwable) {
                // try the next source
            }
        }

        return null;
    }

    private function esc(string $s): string
    {
        return htmlspecialchars($s, ENT_QUOTES | ENT_XML1, 'UTF-8');
    }
}
