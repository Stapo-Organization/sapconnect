<?php

namespace App\Services\Marketing;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;

/**
 * The slider's artwork, composed from the REAL product photos.
 *
 * The generated-scene version was rejected on sight, and rightly: a rendered
 * doorstep is somebody else's shop. What the owner already approved is the
 * bundle card — the catalogue's own packshots, big, tilted, overlapping,
 * floating on soft shadows over an airy ground. This is that composition in
 * the hero's shape, one arrangement per subject:
 *
 *   cascade — three packs falling across the stage, front one biggest
 *   row     — four packs standing in a line on a shelf, «الأكثر طلباً»
 *   burst   — one pack big, two peeking behind it, rays: «وصل حديثاً»
 *   fan     — packs fanned like a hand of cards, tied: «البكجات»
 *   stage   — packs on a coral podium under a spotlight: «التصفية»
 *
 * Deterministic, free, and the same picture on every render. There is NO text
 * in the artwork: the app draws its own live Arabic over it, which is the only
 * way a slide can say «يوصلك الساعة 10:45 م» and still be true a minute later.
 *
 * Rasterised through the same resvg pipeline as the ad engine, so the output
 * is a plain PNG on public storage.
 */
class HeroCollageComposer
{
    /** 3.2:1 — the hero band's own shape, so nothing is cropped away. */
    private const W = 1280;
    private const H = 400;

    /** Where the products live: the app's type takes the other side. */
    private const STAGE_CX = 360;

    /** Everything stands on this line, the way objects stand on a table. */
    private const BASE = 366;

    private const CORAL = '#D46856';

    /**
     * One packshot, cut off its white studio card and written to [$outPath].
     *
     * This is what the app cannot do for itself: half the catalogue is shot on
     * white, and on the slider's deep field those arrive as small white boxes
     * with the product marooned inside. Cut out, the same photo floats.
     *
     * Already-transparent photos are copied through untouched, and a picture
     * whose edges were never white (a lifestyle shot, a composed bundle card)
     * is left exactly as it came.
     */
    public function cutout(string $url, string $outPath): bool
    {
        try {
            $resp = Http::timeout(20)->get($url);
            if (! $resp->successful()) {
                return false;
            }
        } catch (\Throwable $e) {
            return false;
        }

        $dir = dirname($outPath);
        if (! is_dir($dir)) {
            mkdir($dir, 0775, true);
        }

        $composed = str_contains($url, '/creatives/') || str_contains($url, 'bundle-');
        $cut = $composed ? null : $this->knockOutWhite($resp->body());

        return file_put_contents($outPath, $cut ?? $resp->body()) !== false;
    }

    /**
     * One packshot cut off its white card AND trimmed to what is left, written
     * to [$outPath] — or nothing at all.
     *
     * The need tiles float their products on colour, so a photo that was not
     * on white (a lifestyle shot, a composed card) is refused rather than
     * passed through, and so is a cut that left only a sliver or a stray logo.
     * The trim is what makes the app's sizing honest: a 360px card with a
     * 90px tin in the middle would draw as a 360px empty box.
     *
     * @return array{w:int,h:int}|null the written image's size
     */
    public function cutoutTrimmed(string $url, string $outPath): ?array
    {
        if (str_contains($url, '/creatives/') || str_contains($url, 'bundle-')) {
            return null;
        }
        try {
            $resp = Http::timeout(20)->get($url);
            if (! $resp->successful()) {
                return null;
            }
        } catch (\Throwable $e) {
            return null;
        }

        $cut = $this->knockOutWhite($resp->body());
        if ($cut === null) {
            return null;
        }
        $img = @imagecreatefromstring($cut);
        if ($img === false) {
            return null;
        }
        imagealphablending($img, false);
        imagesavealpha($img, true);

        $w = imagesx($img);
        $h = imagesy($img);
        $minX = $w;
        $minY = $h;
        $maxX = -1;
        $maxY = -1;
        // Every other pixel is plenty for a bounding box, and half the cost.
        for ($y = 0; $y < $h; $y += 2) {
            for ($x = 0; $x < $w; $x += 2) {
                if (((imagecolorat($img, $x, $y) >> 24) & 0x7F) < 100) {
                    if ($x < $minX) $minX = $x;
                    if ($x > $maxX) $maxX = $x;
                    if ($y < $minY) $minY = $y;
                    if ($y > $maxY) $maxY = $y;
                }
            }
        }
        if ($maxX < 0) {
            imagedestroy($img);
            return null;
        }
        $bw = $maxX - $minX + 1;
        $bh = $maxY - $minY + 1;
        if ($bw < 40 || $bh < 40 || $bw * $bh < $w * $h * 0.06) {
            imagedestroy($img);
            return null;
        }

        $m = (int) round(max($bw, $bh) * 0.04);
        $x0 = max(0, $minX - $m);
        $y0 = max(0, $minY - $m);
        $crop = imagecrop($img, [
            'x' => $x0,
            'y' => $y0,
            'width' => min($w - $x0, $bw + 2 * $m),
            'height' => min($h - $y0, $bh + 2 * $m),
        ]);
        imagedestroy($img);
        if ($crop === false) {
            return null;
        }
        imagealphablending($crop, false);
        imagesavealpha($crop, true);

        // A tile never needs more than 600px on its long side.
        $cw = imagesx($crop);
        $ch = imagesy($crop);
        $long = max($cw, $ch);
        if ($long > 600) {
            $nw = (int) round($cw * 600 / $long);
            $nh = (int) round($ch * 600 / $long);
            $small = imagecreatetruecolor($nw, $nh);
            imagealphablending($small, false);
            imagesavealpha($small, true);
            imagefill($small, 0, 0, imagecolorallocatealpha($small, 255, 255, 255, 127));
            imagecopyresampled($small, $crop, 0, 0, 0, 0, $nw, $nh, $cw, $ch);
            imagedestroy($crop);
            $crop = $small;
            $cw = $nw;
            $ch = $nh;
        }

        $dir = dirname($outPath);
        if (! is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
        $ok = imagepng($crop, $outPath, 6);
        imagedestroy($crop);

        return $ok ? ['w' => $cw, 'h' => $ch] : null;
    }

    /**
     * @param array<int,string> $imageUrls product photos, best first
     * @return string|null absolute path of the rendered PNG
     */
    public function render(string $theme, array $imageUrls, string $outPath): ?string
    {
        $images = [];
        foreach ($imageUrls as $url) {
            $data = $this->dataUri($url);
            if ($data !== null) {
                $images[] = $data;
            }
            if (count($images) >= 4) {
                break;
            }
        }
        if ($images === []) {
            return null;
        }

        $palette = self::palette($theme);
        $stage = match ($theme) {
            'express_top' => $this->row($images),
            'express_new' => $this->burst($images, $palette),
            'bundles' => $this->fan($images),
            'clearance' => $this->podium($images, $palette),
            default => $this->cascade($images),
        };

        $svg = $this->frame($stage, $palette);

        $dir = dirname($outPath);
        if (! is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
        $svgPath = preg_replace('/\.png$/', '.svg', $outPath) ?: ($outPath . '.svg');
        file_put_contents($svgPath, $svg);

        $node = (string) config('services.creative.node_binary', 'node');
        $result = Process::timeout(60)->run([
            $node,
            base_path('resources/js/render-banner.mjs'),
            $svgPath,
            $outPath,
            resource_path('fonts/cairo'),
        ]);
        @unlink($svgPath);

        return ($result->successful() && is_file($outPath)) ? $outPath : null;
    }

    /**
     * Each subject's own light. The app's type sits on the END side, so every
     * ground darkens that way — the picture hands the words a place to stand.
     *
     * @return array{0:string,1:string,2:string} [near, far, aura]
     */
    public static function palette(string $theme): array
    {
        return match ($theme) {
            // إكسبريس — the branch, in teal.
            'express_clock' => ['#2D7A79', '#0E3130', '#5FC0BE'],
            'express_top' => ['#3E9493', '#123B3A', '#8AD8D6'],
            'express_new' => ['#429D9C', '#0E2E2D', '#F4BE2C'],
            // زوبكسي — the warm half.
            'cutoff' => ['#2C3E2D', '#101613', '#D48644'],
            'bundles' => ['#D48644', '#5A2C1E', '#FFD9A8'],
            'clearance' => ['#D46856', '#4A1C14', '#FFC7BC'],
            default => ['#2D7A79', '#0E3130', '#5FC0BE'],
        };
    }

    /* ═══════════════════════════ the frame ═══════════════════════════ */

    /** @param array{0:string,1:string,2:string} $palette */
    private function frame(string $stage, array $palette): string
    {
        [$near, $far, $aura] = $palette;
        $w = self::W;
        $h = self::H;
        $atmosphere = $this->atmosphere($aura);

        return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="{$w}" height="{$h}" viewBox="0 0 {$w} {$h}">
  <defs>
    <linearGradient id="ground" x1="0" y1="0" x2="1" y2="0.4">
      <stop offset="0" stop-color="{$near}"/>
      <stop offset="0.62" stop-color="{$far}"/>
      <stop offset="1" stop-color="{$far}"/>
    </linearGradient>
    <radialGradient id="aura" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{$aura}" stop-opacity="0.42"/>
      <stop offset="0.65" stop-color="{$aura}" stop-opacity="0.14"/>
      <stop offset="1" stop-color="{$aura}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="softshadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#000000" stop-opacity="0.42"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0"/>
    </radialGradient>
    <filter id="lift" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="16" stdDeviation="18" flood-color="#000000" flood-opacity="0.38"/>
    </filter>
  </defs>

  <rect width="{$w}" height="{$h}" fill="url(#ground)"/>
  {$atmosphere}
  {$stage}
</svg>
SVG;
    }

    /** The air around the products: one big glow, a dashed orbit, faint paws. */
    private function atmosphere(string $aura): string
    {
        $cx = self::STAGE_CX;

        $paw = function (int $x, int $y, float $s, int $rot): string {
            return <<<SVG
  <g transform="translate({$x} {$y}) rotate({$rot}) scale({$s})" fill="#FFFFFF" fill-opacity="0.06">
    <ellipse cx="0" cy="14" rx="30" ry="24"/>
    <ellipse cx="-30" cy="-16" rx="12" ry="16"/>
    <ellipse cx="-10" cy="-26" rx="12" ry="16"/>
    <ellipse cx="10" cy="-26" rx="12" ry="16"/>
    <ellipse cx="30" cy="-16" rx="12" ry="16"/>
  </g>
SVG;
        };

        return <<<SVG
  <circle cx="{$cx}" cy="230" r="330" fill="url(#aura)"/>
  <circle cx="{$cx}" cy="230" r="268" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"
          stroke-width="2" stroke-dasharray="1 13" stroke-linecap="round"/>
  {$paw(1120, 92, 0.9, 16)}
  {$paw(150, 330, 0.7, -12)}
  <circle cx="742" cy="120" r="6" fill="#FFFFFF" fill-opacity="0.35"/>
  <circle cx="86" cy="150" r="9" fill="#FFFFFF" fill-opacity="0.22"/>
SVG;
    }

    /* ═══════════════════════════ the stages ═══════════════════════════ */

    /** Three packs falling across the stage, the front one biggest. */
    private function cascade(array $images): string
    {
        $cx = self::STAGE_CX;
        $out = [$this->shadow($cx, self::BASE + 6, 330, 40)];

        // back → front, so the biggest lands on top. Sizes are a third of the
        // band's height apart, which is what makes a stack read as depth
        // rather than as three things that happen to overlap.
        $plan = [
            [2, $cx - 210, 236, -14, 0.82],
            [1, $cx + 120, 264, 12, 0.90],
            [0, $cx - 55, 318, -3, 1.0],
        ];
        foreach ($plan as [$i, $x, $size, $rot, $opacity]) {
            $img = $images[$i] ?? $images[count($images) - 1];
            $y = self::BASE - $size;
            $out[] = "<g filter=\"url(#lift)\" opacity=\"{$opacity}\" transform=\"rotate({$rot} " . ($x + $size / 2) . ' ' . ($y + $size / 2) . ")\">"
                . "<image href=\"{$img}\" x=\"{$x}\" y=\"{$y}\" width=\"{$size}\" height=\"{$size}\"/></g>";
        }

        return implode("\n  ", $out);
    }

    /** Four packs standing in a line, on a shelf of light. */
    private function row(array $images): string
    {
        $count = min(4, count($images));
        $size = 240;
        $overlap = 46;                       // they lean on each other, like stock
        $step = $size - $overlap;
        $left = max(28.0, self::STAGE_CX + 210 - ($count - 1) * $step - $size / 2);
        $y = self::BASE - $size;

        $shelfX = (int) ($left - 40);
        $shelfW = (int) (($count - 1) * $step + $size + 80);
        $out = [
            "<rect x=\"{$shelfX}\" y=\"" . (self::BASE + 4) . "\" width=\"{$shelfW}\" height=\"4\" rx=\"2\" fill=\"#FFFFFF\" fill-opacity=\"0.20\"/>",
        ];
        for ($i = 0; $i < $count; $i++) {
            $x = (int) ($left + $i * $step);
            $out[] = $this->shadow((int) ($x + $size / 2), self::BASE + 4, 118, 18);
            $out[] = "<g filter=\"url(#lift)\"><image href=\"{$images[$i]}\" x=\"{$x}\" y=\"{$y}\" width=\"{$size}\" height=\"{$size}\"/></g>";
        }

        return implode("\n  ", $out);
    }

    /** One pack, big, with rays behind it — the thing that just landed. */
    private function burst(array $images, array $palette): string
    {
        [, , $aura] = $palette;
        $cx = self::STAGE_CX;
        $cy = 210;

        $rays = [];
        for ($i = 0; $i < 12; $i++) {
            $rays[] = "<rect x=\"" . ($cx - 3) . "\" y=\"" . ($cy - 250) . "\" width=\"6\" height=\"150\" rx=\"3\" fill=\"{$aura}\" fill-opacity=\"0.18\""
                . " transform=\"rotate(" . ($i * 30) . " {$cx} {$cy})\"/>";
        }

        $out = array_merge($rays, [$this->shadow($cx, self::BASE + 6, 300, 36)]);
        foreach ([[1, -1], [2, 1]] as [$i, $side]) {
            if (! isset($images[$i])) {
                continue;
            }
            $size = 214;
            $x = $cx + $side * 190 - $size / 2;
            $out[] = "<g opacity=\"0.75\" transform=\"rotate(" . ($side * 15) . ' ' . ($x + $size / 2) . ' ' . (self::BASE - $size / 2) . ")\">"
                . "<image href=\"{$images[$i]}\" x=\"{$x}\" y=\"" . (self::BASE - $size) . "\" width=\"{$size}\" height=\"{$size}\"/></g>";
        }
        $hero = 330;
        $out[] = "<g filter=\"url(#lift)\"><image href=\"{$images[0]}\" x=\"" . ($cx - $hero / 2) . "\" y=\"" . (self::BASE - $hero) . "\" width=\"{$hero}\" height=\"{$hero}\"/></g>";

        return implode("\n  ", $out);
    }

    /** Packs fanned like a hand of cards — several things bought as one. */
    private function fan(array $images): string
    {
        $cx = self::STAGE_CX;
        $out = [$this->shadow($cx, self::BASE + 6, 340, 38)];

        $plan = [[-20, -200, 250], [0, 0, 300], [20, 200, 250]];
        foreach ($plan as $i => [$rot, $dx, $size]) {
            $img = $images[$i] ?? $images[count($images) - 1];
            $x = $cx + $dx - $size / 2;
            $y = self::BASE - $size;
            $out[] = "<g filter=\"url(#lift)\" transform=\"rotate({$rot} " . ($x + $size / 2) . ' ' . ($y + $size / 2) . ")\">"
                . "<image href=\"{$img}\" x=\"{$x}\" y=\"{$y}\" width=\"{$size}\" height=\"{$size}\"/></g>";
        }

        return implode("\n  ", $out);
    }

    /** Packs on a coral podium under a spotlight — the sale stage. */
    private function podium(array $images, array $palette): string
    {
        $cx = self::STAGE_CX;
        $coral = self::CORAL;
        $top = self::BASE - 6;

        $out = [
            "<ellipse cx=\"{$cx}\" cy=\"" . ($top + 16) . "\" rx=\"290\" ry=\"44\" fill=\"{$coral}\" fill-opacity=\"0.5\"/>",
            "<ellipse cx=\"{$cx}\" cy=\"{$top}\" rx=\"290\" ry=\"44\" fill=\"{$coral}\"/>",
        ];

        $plan = [[-195, 224, -9], [0, 296, 0], [195, 224, 9]];
        foreach ($plan as $i => [$dx, $size, $rot]) {
            $img = $images[$i] ?? $images[count($images) - 1];
            $x = $cx + $dx - $size / 2;
            $y = $top - $size + 12;
            $out[] = "<g filter=\"url(#lift)\" transform=\"rotate({$rot} " . ($x + $size / 2) . ' ' . ($y + $size / 2) . ")\">"
                . "<image href=\"{$img}\" x=\"{$x}\" y=\"{$y}\" width=\"{$size}\" height=\"{$size}\"/></g>";
        }

        // Confetti over the stage only — a sale is loud, but on one side.
        for ($i = 0; $i < 16; $i++) {
            $x = $cx - 300 + ($i * 41) % 600;
            $y = 24 + ($i * 57) % 200;
            $r = 6 + ($i % 3) * 3;
            $fill = $i % 2 === 0 ? '#FFF7EF' : '#FFD9A8';
            $out[] = "<rect x=\"{$x}\" y=\"{$y}\" width=\"{$r}\" height=\"" . ($r * 2) . "\" rx=\"2\" fill=\"{$fill}\" fill-opacity=\"0.5\" transform=\"rotate(" . ($i * 27) . " {$x} {$y})\"/>";
        }

        return implode("\n  ", $out);
    }

    private function shadow(int $cx, int $cy, int $rx, int $ry): string
    {
        return "<ellipse cx=\"{$cx}\" cy=\"{$cy}\" rx=\"{$rx}\" ry=\"{$ry}\" fill=\"url(#softshadow)\"/>";
    }

    /* ═══════════════════════════ plumbing ═══════════════════════════ */

    /**
     * A product photo as a data URI, with its white studio background knocked
     * out — resvg fetches nothing itself, and a packshot still sitting on its
     * white card reads as a white card, not as a product floating on the
     * slide. Half the catalogue is shot on white and half is already cut out,
     * so this makes them agree.
     */
    private function dataUri(string $url): ?string
    {
        try {
            $resp = Http::timeout(20)->get($url);
            if (! $resp->successful()) {
                return null;
            }
            $mime = (string) ($resp->header('Content-Type') ?: 'image/png');
            if (! str_starts_with($mime, 'image/')) {
                return null;
            }

            // A bundle card is already a composition — cream ground, coral
            // seal, its own shadow. Flooding its background out leaves ragged
            // white islands and a seal floating in mid-air.
            $composed = str_contains($url, '/creatives/') || str_contains($url, 'bundle-');
            $cut = $composed ? null : $this->knockOutWhite($resp->body());

            return $cut !== null
                ? 'data:image/png;base64,' . base64_encode($cut)
                : 'data:' . $mime . ';base64,' . base64_encode($resp->body());
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * Flood the near-white background in from the edges and make it
     * transparent.
     *
     * Only from the BORDER, and only through near-white: a white label in the
     * middle of a pack is enclosed by the pack's own edges, so the flood never
     * reaches it. Anything already cut out arrives with a transparent border
     * and comes straight back.
     */
    private function knockOutWhite(string $bytes): ?string
    {
        if (! function_exists('imagecreatefromstring')) {
            return null;
        }

        $src = @imagecreatefromstring($bytes);
        if ($src === false) {
            return null;
        }

        $w = imagesx($src);
        $h = imagesy($src);
        if ($w < 8 || $h < 8 || $w * $h > 1_500_000) {
            imagedestroy($src);
            return null;
        }

        $img = imagecreatetruecolor($w, $h);
        imagealphablending($img, false);
        imagesavealpha($img, true);
        imagecopy($img, $src, 0, 0, 0, 0, $w, $h);
        imagedestroy($src);

        $white = static function (int $rgb): bool {
            if ((($rgb >> 24) & 0x7F) > 100) {
                return true; // already transparent
            }
            $r = ($rgb >> 16) & 0xFF;
            $g = ($rgb >> 8) & 0xFF;
            $b = $rgb & 0xFF;
            // Bright and unsaturated — a studio sweep, not a product colour.
            return $r > 233 && $g > 233 && $b > 233 && (max($r, $g, $b) - min($r, $g, $b)) < 14;
        };

        // A byte per pixel and a queue of packed ints: the obvious version —
        // an array of [x, y] pairs and a keyed `seen` map — needs hundreds of
        // megabytes on a 1000px packshot and takes the whole command down.
        $seen = str_repeat("\0", $w * $h);
        $queue = [];
        for ($x = 0; $x < $w; $x++) {
            $queue[] = $x;
            $queue[] = ($h - 1) * $w + $x;
        }
        for ($y = 0; $y < $h; $y++) {
            $queue[] = $y * $w;
            $queue[] = $y * $w + ($w - 1);
        }

        $clear = imagecolorallocatealpha($img, 255, 255, 255, 127);
        $painted = 0;
        $head = 0;
        while ($head < count($queue)) {
            $key = $queue[$head++];
            if ($seen[$key] === "\1") {
                continue;
            }
            $seen[$key] = "\1";

            $x = $key % $w;
            $y = intdiv($key, $w);
            if (! $white(imagecolorat($img, $x, $y))) {
                continue;
            }
            imagesetpixel($img, $x, $y, $clear);
            $painted++;

            if ($x + 1 < $w) $queue[] = $key + 1;
            if ($x > 0) $queue[] = $key - 1;
            if ($y + 1 < $h) $queue[] = $key + $w;
            if ($y > 0) $queue[] = $key - $w;

            // The queue is drained from the front and never compacted; on a
            // mostly-white photo that grows without bound, so it is cut loose
            // once the read head has passed a long stretch of it.
            if ($head > 200000) {
                $queue = array_slice($queue, $head);
                $head = 0;
            }
        }

        // A photograph whose edges were never white (a lifestyle shot, a card)
        // is left exactly as it came.
        if ($painted < ($w * $h) * 0.02) {
            imagedestroy($img);
            return null;
        }

        ob_start();
        imagepng($img, null, 6);
        $out = (string) ob_get_clean();
        imagedestroy($img);

        return $out;
    }
}
