<?php

namespace App\Services\Marketing;

use App\Models\Product;
use App\Models\ProductBundle;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;

/**
 * The bundle's product-card artwork — composed deterministically from the
 * REAL catalog photos (no AI, no cost, same picture every render).
 *
 * v3, after the owner's review: almost NO text in the artwork. The app card
 * already says the name, the math, the price and the saving — so the image's
 * whole job is the PRODUCTS: big, tilted, overlapping, floating on soft
 * shadows over a light airy ground with a teal aura and coral sparks. The
 * only lettering left is the coral starburst seal («+N مجاناً», Tajawal —
 * the one face that rasterises crisply at card size).
 *
 *   stacking   — the product fanned into a tilted stack
 *   variety    — the flavours as an overlapping cascade
 *   companion / smart_gift — big anchor + the gift, joined by a coral plus
 *
 * Rendered via the same resvg pipeline as the ad engine (render-banner.mjs).
 */
class BundleCardComposer
{
    private const W = 1000;
    private const H = 1000;

    private const TEAL = '#3E9493';
    private const TEAL_DEEP = '#2C6B6A';
    private const CORAL = '#D46856';
    private const CORAL_DEEP = '#B24E3D';

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
            'stacking' => $this->stackingStage($anchorImg),
            'variety' => $this->varietyStage($bundle),
            default => $this->giftStage($bundle, $anchorImg),
        };
        if ($stage === null) {
            return null;
        }

        [, $free] = $this->ladderOf($bundle);
        $seal = $this->seal(180, 210, $free > 0 ? "+{$free}" : '');

        $w = self::W;
        $h = self::H;
        $atmosphere = $this->atmosphere();

        return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="{$w}" height="{$h}" viewBox="0 0 {$w} {$h}">
  <defs>
    <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FDFCFA"/>
      <stop offset="1" stop-color="#EBF2F1"/>
    </linearGradient>
    <radialGradient id="aura" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{$this->tealAt()}" stop-opacity="0.22"/>
      <stop offset="0.7" stop-color="{$this->tealAt()}" stop-opacity="0.10"/>
      <stop offset="1" stop-color="{$this->tealAt()}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="softshadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#3C4A48" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#3C4A48" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="{$w}" height="{$h}" fill="url(#ground)"/>
  {$atmosphere}
  {$stage}
  {$seal}
</svg>
SVG;
    }

    private function tealAt(): string
    {
        return self::TEAL;
    }

    /**
     * The airy ground behind the products: a big teal aura, one offset coral
     * ring, faint paws, and a few coral sparks — atmosphere, not a frame.
     */
    private function atmosphere(): string
    {
        $teal = self::TEAL;
        $tealDeep = self::TEAL_DEEP;
        $coral = self::CORAL;

        $spark = function (int $cx, int $cy, int $r, float $opacity) use ($coral): string {
            $r2 = (int) round($r * 0.36);
            return "<path d=\"M{$cx} " . ($cy - $r) . " Q{$cx} " . ($cy - $r2) . ' ' . ($cx + $r) . " {$cy} Q{$cx} " . ($cy + $r2) . " {$cx} " . ($cy + $r)
                . " Q{$cx} " . ($cy + $r2) . ' ' . ($cx - $r) . " {$cy} Q{$cx} " . ($cy - $r2) . " {$cx} " . ($cy - $r)
                . " Z\" fill=\"{$coral}\" fill-opacity=\"{$opacity}\"/>";
        };

        $paw = function (int $x, int $y, float $s, int $rot) use ($tealDeep): string {
            return <<<SVG
  <g transform="translate({$x} {$y}) rotate({$rot}) scale({$s})" fill="{$tealDeep}" fill-opacity="0.05">
    <ellipse cx="0" cy="14" rx="30" ry="24"/>
    <ellipse cx="-30" cy="-16" rx="12" ry="16"/>
    <ellipse cx="-10" cy="-26" rx="12" ry="16"/>
    <ellipse cx="10" cy="-26" rx="12" ry="16"/>
    <ellipse cx="30" cy="-16" rx="12" ry="16"/>
  </g>
SVG;
        };

        return <<<SVG
  <circle cx="500" cy="480" r="400" fill="url(#aura)"/>
  <circle cx="620" cy="420" r="330" fill="none" stroke="{$teal}" stroke-opacity="0.14" stroke-width="3" stroke-dasharray="1 14" stroke-linecap="round"/>
  <circle cx="330" cy="640" r="210" fill="none" stroke="{$coral}" stroke-opacity="0.12" stroke-width="2.5"/>
  {$paw(905, 900, 1.3, 18)}
  {$paw(95, 165, 0.95, -14)}
  {$spark(862, 250, 26, 0.75)}
  {$spark(120, 725, 18, 0.55)}
  {$spark(915, 660, 13, 0.45)}
  <circle cx="150" cy="530" r="7" fill="{$teal}" fill-opacity="0.30"/>
  <circle cx="845" cy="470" r="9" fill="{$coral}" fill-opacity="0.28"/>
SVG;
    }

    /** The product fanned into a tilted stack — bigger, deeper overlap. */
    private function stackingStage(string $img): string
    {
        return <<<SVG
  <ellipse cx="500" cy="855" rx="330" ry="42" fill="url(#softshadow)"/>
  <g transform="rotate(-3 500 520)">
    <image href="{$img}" x="130" y="205" width="500" height="500" transform="rotate(-13 380 455)" opacity="0.88"/>
    <image href="{$img}" x="370" y="205" width="500" height="500" transform="rotate(13 620 455)" opacity="0.94"/>
    <image href="{$img}" x="235" y="265" width="540" height="540"/>
  </g>
SVG;
    }

    /** The flavours as an overlapping cascade, front one biggest. */
    private function varietyStage(ProductBundle $bundle): ?string
    {
        $members = $bundle->items->take(5)->values();
        $images = [];
        foreach ($members as $m) {
            $uri = $this->imageDataUri($m->item_code);
            if ($uri !== null) {
                $images[] = $uri;
            }
        }
        $n = count($images);
        if ($n < 2) {
            return null;
        }

        // Back-to-front cascade across the canvas; the front item leads.
        // Slots tuned for 3–5 items: [x, y, size, rotation, opacity].
        $slots = match ($n) {
            2 => [[180, 330, 380, -8, .95], [420, 300, 460, 5, 1]],
            3 => [[120, 330, 360, -10, .9], [560, 330, 360, 10, .95], [320, 290, 440, 0, 1]],
            4 => [[90, 350, 330, -12, .88], [590, 350, 330, 12, .92], [230, 320, 380, -4, .96], [420, 290, 430, 4, 1]],
            default => [[70, 370, 300, -14, .85], [640, 370, 300, 14, .88], [190, 340, 340, -7, .92], [480, 330, 360, 7, .96], [320, 300, 420, 0, 1]],
        };

        $out = "\n  <ellipse cx=\"500\" cy=\"850\" rx=\"360\" ry=\"40\" fill=\"url(#softshadow)\"/>";
        foreach ($slots as $i => [$x, $y, $size, $rot, $opacity]) {
            $img = $images[$i];
            $cx = $x + (int) ($size / 2);
            $cy = $y + (int) ($size / 2);
            $out .= "\n  <image href=\"{$img}\" x=\"{$x}\" y=\"{$y}\" width=\"{$size}\" height=\"{$size}\" transform=\"rotate({$rot} {$cx} {$cy})\" opacity=\"{$opacity}\"/>";
        }

        return $out;
    }

    /** Big anchor + the gift leaning in, joined by a coral plus. */
    private function giftStage(ProductBundle $bundle, string $anchorImg): ?string
    {
        $gift = $bundle->items->firstWhere('role', 'gift');
        $giftImg = $gift ? $this->imageDataUri($gift->item_code) : null;
        $coral = self::CORAL;
        $coralDeep = self::CORAL_DEEP;

        if ($gift === null || $giftImg === null) {
            return <<<SVG
  <ellipse cx="500" cy="850" rx="300" ry="38" fill="url(#softshadow)"/>
  <image href="{$anchorImg}" x="215" y="200" width="570" height="640" preserveAspectRatio="xMidYMid meet" transform="rotate(3 500 520)"/>
SVG;
        }

        $qty = (int) $gift->qty;
        $qtyChip = '';
        if ($qty > 1) {
            $qtyChip = <<<SVG
  <g transform="rotate(-8 385 425)">
    <circle cx="385" cy="425" r="48" fill="{$coralDeep}"/>
    <text x="385" y="440" text-anchor="middle" font-family="Tajawal" font-size="42" font-weight="700" fill="#FFFFFF">×{$qty}</text>
  </g>
SVG;
        }

        return <<<SVG
  <ellipse cx="640" cy="858" rx="260" ry="36" fill="url(#softshadow)"/>
  <ellipse cx="255" cy="820" rx="180" ry="28" fill="url(#softshadow)"/>
  <image href="{$anchorImg}" x="360" y="180" width="580" height="660" preserveAspectRatio="xMidYMid meet" transform="rotate(3 650 510)"/>
  <image href="{$giftImg}" x="80" y="430" width="350" height="380" preserveAspectRatio="xMidYMid meet" transform="rotate(-6 255 620)"/>
  <g transform="rotate(-8 420 585)">
    <rect x="378" y="570" width="84" height="30" rx="15" fill="{$coral}"/>
    <rect x="405" y="543" width="30" height="84" rx="15" fill="{$coral}"/>
  </g>
  {$qtyChip}
SVG;
    }

    /**
     * The coral starburst seal — the ONE piece of lettering the artwork
     * keeps. Tajawal only: it is the face that stays crisp at card size.
     */
    private function seal(int $cx, int $cy, string $top): string
    {
        $coral = self::CORAL;
        $coralDeep = self::CORAL_DEEP;
        $star = $this->starPath($cx, $cy, 118, 106, 16);
        $starBack = $this->starPath($cx + 6, $cy + 9, 118, 106, 16);
        $topLine = $top !== ''
            ? '<text x="' . $cx . '" y="' . ($cy - 4) . '" text-anchor="middle" font-family="Tajawal" font-size="58" font-weight="700" fill="#FFFFFF">' . $this->esc($top) . '</text>'
            : '';
        $wordY = $top !== '' ? $cy + 48 : $cy + 16;
        $wordSize = $top !== '' ? 37 : 42;

        return <<<SVG
  <g transform="rotate(-10 {$cx} {$cy})">
    <path d="{$starBack}" fill="{$coralDeep}" fill-opacity="0.45"/>
    <path d="{$star}" fill="{$coral}"/>
    <circle cx="{$cx}" cy="{$cy}" r="79" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" stroke-dasharray="2 11" stroke-linecap="round"/>
    {$topLine}
    <text x="{$cx}" y="{$wordY}" text-anchor="middle" font-family="Tajawal" font-size="{$wordSize}" font-weight="700" fill="#FFFFFF">مجاناً</text>
  </g>
SVG;
    }

    /** A starburst path (alternating outer/inner radius). */
    private function starPath(int $cx, int $cy, int $rOut, int $rIn, int $points): string
    {
        $steps = $points * 2;
        $d = '';
        for ($i = 0; $i < $steps; $i++) {
            $r = $i % 2 === 0 ? $rOut : $rIn;
            $a = M_PI * $i / $points - M_PI / 2;
            $x = round($cx + $r * cos($a), 1);
            $y = round($cy + $r * sin($a), 1);
            $d .= ($i === 0 ? 'M' : 'L') . $x . ' ' . $y . ' ';
        }
        return trim($d) . ' Z';
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
