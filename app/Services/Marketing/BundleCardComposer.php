<?php

namespace App\Services\Marketing;

use App\Models\Product;
use App\Models\ProductBundle;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;

/**
 * The bundle's product-card image — composed deterministically from the REAL
 * catalog photos (no AI, no cost, same picture every render), in Zooboxi's
 * consumer identity: a deep-teal ground with soft paw ornaments, a floating
 * white stage carrying the products with soft shadows, a coral starburst
 * seal for «مجاناً», and the deal math set big in Aref Ruqaa on the base.
 *
 *   stacking   — the product fanned into a stack
 *   variety    — the flavours side by side, each with its count
 *   companion / smart_gift — big anchor + the gift, joined by a coral plus
 *
 * Rendered via the same resvg pipeline as the ad engine (render-banner.mjs).
 */
class BundleCardComposer
{
    private const W = 1000;
    private const H = 1000;

    private const TEAL = '#3E9493';
    private const TEAL_DEEP = '#275F5E';
    private const TEAL_DARK = '#1C4746';
    private const CORAL = '#D46856';
    private const CORAL_DEEP = '#B24E3D';
    private const BONE = '#F6F4EF';
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
            'stacking' => $this->stackingStage($anchorImg),
            'variety' => $this->varietyStage($bundle),
            default => $this->giftStage($bundle, $anchorImg),
        };
        if ($stage === null) {
            return null;
        }

        [$paid, $free] = $this->ladderOf($bundle);
        $sealTop = $free > 0 ? "+{$free}" : '';

        $w = self::W;
        $h = self::H;
        $teal = self::TEAL;
        $tealDeep = self::TEAL_DEEP;
        $tealDark = self::TEAL_DARK;
        $bone = self::BONE;
        $coral = self::CORAL;

        $wordmark = $this->esc('حزم زوبوكسي');
        $speciesChip = $this->esc($this->speciesWord($bundle->species));
        $headline = $this->esc($this->headline($bundle));
        $subline = $this->esc($this->subline($bundle));
        $ornaments = $this->ornaments();
        $seal = $this->seal(196, 236, $sealTop, 'مجاناً');

        return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="{$w}" height="{$h}" viewBox="0 0 {$w} {$h}">
  <defs>
    <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{$tealDeep}"/>
      <stop offset="0.55" stop-color="{$teal}"/>
      <stop offset="1" stop-color="{$tealDeep}"/>
    </linearGradient>
    <linearGradient id="stage" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#F4F1E9"/>
    </linearGradient>
    <radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{$tealDark}" stop-opacity="0.45"/>
      <stop offset="1" stop-color="{$tealDark}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="softshadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#8A8272" stop-opacity="0.38"/>
      <stop offset="1" stop-color="#8A8272" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="{$w}" height="{$h}" fill="url(#ground)"/>
  {$ornaments}

  <!-- header -->
  <g font-family="Tajawal">
    <circle cx="936" cy="86" r="9" fill="{$coral}"/>
    <text x="916" y="101" text-anchor="end" font-size="46" font-weight="700" fill="{$bone}">{$wordmark}</text>
    <rect x="64" y="52" width="196" height="66" rx="33" fill="{$bone}" fill-opacity="0.16"/>
    <text x="162" y="97" text-anchor="middle" font-size="34" font-weight="700" fill="{$bone}">{$speciesChip}</text>
  </g>

  <!-- floating stage -->
  <ellipse cx="500" cy="812" rx="420" ry="46" fill="url(#shadow)"/>
  <rect x="60" y="156" width="880" height="644" rx="48" fill="url(#stage)"/>
  <rect x="60" y="156" width="880" height="644" rx="48" fill="none" stroke="{$bone}" stroke-opacity="0.5" stroke-width="2"/>
  {$stage}
  {$seal}

  <!-- deal math on the base -->
  <text x="500" y="906" text-anchor="middle" font-family="Aref Ruqaa" font-size="76" font-weight="700" fill="{$bone}">{$headline}</text>
  <rect x="400" y="928" width="200" height="7" rx="3.5" fill="{$coral}"/>
  <text x="500" y="978" text-anchor="middle" font-family="Tajawal" font-size="33" font-weight="500" fill="{$bone}" fill-opacity="0.85">{$subline}</text>
</svg>
SVG;
    }

    /** The product fanned into a stack over a soft shadow. */
    private function stackingStage(string $img): string
    {
        return <<<SVG
  <ellipse cx="500" cy="712" rx="300" ry="38" fill="url(#softshadow)"/>
  <g>
    <image href="{$img}" x="215" y="220" width="420" height="420" transform="rotate(-9 425 430)" opacity="0.9"/>
    <image href="{$img}" x="365" y="220" width="420" height="420" transform="rotate(9 575 430)" opacity="0.95"/>
    <image href="{$img}" x="275" y="252" width="450" height="450"/>
  </g>
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
        $cell = (int) min(250, floor(820 / $n));
        $totalW = $cell * $n;
        $x0 = (int) ((self::W - $totalW) / 2);
        $y = (int) (450 - $cell / 2);
        $coral = self::CORAL;

        $out = '';
        foreach ($images as $i => $entry) {
            $x = $x0 + $i * $cell;
            $imgW = $cell - 14;
            $qty = $entry['qty'];
            $cx = $x + (int) ($cell / 2);
            $halfShadow = (int) ($imgW / 2);
            $sy = $y + $imgW + 10;
            $chipX = $cx - 38;
            $chipY = $y + $imgW + 24;
            $chipTextY = $chipY + 32;
            $out .= <<<SVG
  <ellipse cx="{$cx}" cy="{$sy}" rx="{$halfShadow}" ry="14" fill="url(#softshadow)"/>
  <image href="{$entry['img']}" x="{$x}" y="{$y}" width="{$imgW}" height="{$imgW}"/>
  <rect x="{$chipX}" y="{$chipY}" width="76" height="44" rx="22" fill="{$coral}"/>
  <text x="{$cx}" y="{$chipTextY}" text-anchor="middle" font-family="Tajawal" font-size="30" font-weight="700" fill="#FFFFFF">×{$qty}</text>
SVG;
        }

        return $out;
    }

    /** Big anchor + the gift, joined by a coral plus. */
    private function giftStage(ProductBundle $bundle, string $anchorImg): ?string
    {
        $gift = $bundle->items->firstWhere('role', 'gift');
        $giftImg = $gift ? $this->imageDataUri($gift->item_code) : null;
        $coral = self::CORAL;
        $coralDeep = self::CORAL_DEEP;

        if ($gift === null || $giftImg === null) {
            return <<<SVG
  <ellipse cx="500" cy="728" rx="280" ry="34" fill="url(#softshadow)"/>
  <image href="{$anchorImg}" x="255" y="200" width="490" height="540" preserveAspectRatio="xMidYMid meet"/>
SVG;
        }

        $qty = (int) $gift->qty;
        $qtyChip = '';
        if ($qty > 1) {
            $qtyChip = <<<SVG
  <circle cx="352" cy="392" r="42" fill="{$coralDeep}"/>
  <text x="352" y="406" text-anchor="middle" font-family="Tajawal" font-size="36" font-weight="700" fill="#FFFFFF">×{$qty}</text>
SVG;
        }

        return <<<SVG
  <ellipse cx="668" cy="738" rx="230" ry="32" fill="url(#softshadow)"/>
  <ellipse cx="238" cy="700" rx="150" ry="24" fill="url(#softshadow)"/>
  <image href="{$anchorImg}" x="428" y="196" width="480" height="550" preserveAspectRatio="xMidYMid meet"/>
  <image href="{$giftImg}" x="92" y="380" width="290" height="316" preserveAspectRatio="xMidYMid meet"/>
  <g transform="rotate(-8 405 520)">
    <rect x="369" y="507" width="72" height="26" rx="13" fill="{$coral}"/>
    <rect x="392" y="484" width="26" height="72" rx="13" fill="{$coral}"/>
  </g>
  {$qtyChip}
SVG;
    }

    /** The coral starburst «مجاناً» seal, tilted like a hand-placed sticker. */
    private function seal(int $cx, int $cy, string $top, string $word): string
    {
        $coral = self::CORAL;
        $coralDeep = self::CORAL_DEEP;
        $star = $this->starPath($cx, $cy, 128, 116, 16);
        $starBack = $this->starPath($cx + 7, $cy + 9, 128, 116, 16);
        $word = $this->esc($word);
        $topLine = $top !== ''
            ? '<text x="' . $cx . '" y="' . ($cy - 6) . '" text-anchor="middle" font-family="Tajawal" font-size="60" font-weight="700" fill="#FFFFFF">' . $this->esc($top) . '</text>'
            : '';
        $wordY = $top !== '' ? $cy + 50 : $cy + 18;
        $wordSize = $top !== '' ? 40 : 48;

        return <<<SVG
  <g transform="rotate(-10 {$cx} {$cy})">
    <path d="{$starBack}" fill="{$coralDeep}" fill-opacity="0.55"/>
    <path d="{$star}" fill="{$coral}"/>
    <circle cx="{$cx}" cy="{$cy}" r="86" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" stroke-dasharray="2 11" stroke-linecap="round"/>
    {$topLine}
    <text x="{$cx}" y="{$wordY}" text-anchor="middle" font-family="Tajawal" font-size="{$wordSize}" font-weight="700" fill="#FFFFFF">{$word}</text>
  </g>
SVG;
    }

    /** A rounded starburst path (alternating outer/inner radius). */
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

    /** Soft paw-print ornaments on the teal ground. */
    private function ornaments(): string
    {
        $bone = self::BONE;
        $paw = function (int $x, int $y, float $s, int $rot) use ($bone): string {
            return <<<SVG
  <g transform="translate({$x} {$y}) rotate({$rot}) scale({$s})" fill="{$bone}" fill-opacity="0.07">
    <ellipse cx="0" cy="14" rx="30" ry="24"/>
    <ellipse cx="-30" cy="-16" rx="12" ry="16"/>
    <ellipse cx="-10" cy="-26" rx="12" ry="16"/>
    <ellipse cx="10" cy="-26" rx="12" ry="16"/>
    <ellipse cx="30" cy="-16" rx="12" ry="16"/>
  </g>
SVG;
        };

        return $paw(120, 940, 1.5, -18)
            . $paw(895, 175, 1.1, 22)
            . $paw(60, 400, 0.9, 12)
            . "\n  <circle cx=\"985\" cy=\"620\" r=\"170\" fill=\"{$bone}\" fill-opacity=\"0.04\"/>"
            . "\n  <circle cx=\"15\" cy=\"120\" r=\"130\" fill=\"{$bone}\" fill-opacity=\"0.04\"/>";
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

    private function headline(ProductBundle $bundle): string
    {
        [$paid, $free] = $this->ladderOf($bundle);
        if ($paid > 0) {
            return "{$paid} + {$free} مجاناً";
        }
        $gift = $bundle->items->firstWhere('role', 'gift');
        if ($gift) {
            return $gift->qty > 1 ? "{$gift->qty} هدايا معه" : 'وهدية معه';
        }
        return 'بكج زوبوكسي';
    }

    private function subline(ProductBundle $bundle): string
    {
        [$paid, $free] = $this->ladderOf($bundle);
        if ($paid > 0) {
            $total = $paid + $free;
            return "الإجمالي {$total} قطعة — تدفع ثمن {$paid} فقط";
        }
        $gift = $bundle->items->firstWhere('role', 'gift');
        if ($gift) {
            return 'اشترِ الأساسي واستلم الهدية عليه';
        }
        return (string) ($bundle->subtitle_ar ?? '');
    }

    private function speciesWord(string $species): string
    {
        return match ($species) {
            'cat' => 'للقطط 🐱', 'dog' => 'للكلاب 🐶', 'bird' => 'للطيور',
            'small_pet' => 'للقوارض', default => 'لأليفك',
        };
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
