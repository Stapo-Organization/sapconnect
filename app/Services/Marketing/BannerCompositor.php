<?php

namespace App\Services\Marketing;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Composites the final ad banner from a brand/house design kit: AI scene (product
 * on the left) + a calligraphic gold-gradient Arabic headline + clean body/CTA +
 * corner ornaments + the brand's real logo. Rasterised by Node + resvg-js
 * (correct Arabic shaping, no browser). The AI never renders text.
 *
 * $opts carries the resolved kit:
 *   accent, accent_dark, gold, headline_font, body_font, logo_image, logo_text, path
 */
class BannerCompositor
{
    /** format => [width, height, base aspect ratio] */
    public const FORMATS = [
        'hero' => [1600, 600, '16:9'],
        'wide' => [1200, 300, '16:9'],
        'card' => [600, 600, '1:1'],
        'strip' => [1000, 180, '16:9'],
    ];

    private const SCRIM = '#081e28';

    public function render(string $format, array $copy, ?string $baseImagePath, ?string $productImageUrl = null, array $opts = []): ?string
    {
        [$w, $h] = self::FORMATS[$format] ?? self::FORMATS['hero'];

        $kit = [
            'accent' => $opts['accent'] ?? '#0d9488',
            'accent_dark' => $opts['accent_dark'] ?? '#0a5560',
            'gold' => $opts['gold'] ?? '#F4BE2C',
            'headline_font' => $opts['headline_font'] ?? 'Cairo',
            'body_font' => $opts['body_font'] ?? 'Cairo',
            'logo_image' => $opts['logo_image'] ?? null,
            'logo_text' => $opts['logo_text'] ?? 'منتجات',
        ];

        $svg = $this->buildSvg($w, $h, $copy, $baseImagePath, $kit);

        Storage::disk('local')->put('creative-tmp/' . ($svgRel = Str::uuid() . '.svg'), $svg);
        $svgAbs = Storage::disk('local')->path('creative-tmp/' . $svgRel);

        $relative = $opts['path'] ?? ('creatives/out/' . Str::uuid() . '-' . $format . '.png');
        Storage::disk('public')->put($relative, '');
        $outAbs = Storage::disk('public')->path($relative);

        $node = (string) config('services.creative.node_binary', 'node');
        $script = base_path('resources/js/render-banner.mjs');
        $fontDir = base_path('resources/fonts/cairo');

        $result = Process::timeout(60)->run([$node, $script, $svgAbs, $outAbs, $fontDir]);
        Storage::disk('local')->delete('creative-tmp/' . $svgRel);

        if (! is_file($outAbs) || filesize($outAbs) < 512) {
            Log::error('[creative] resvg render failed', ['exit' => $result->exitCode(), 'err' => $result->errorOutput(), 'out' => $result->output()]);
            return null;
        }

        return $outAbs;
    }

    private function buildSvg(int $w, int $h, array $copy, ?string $baseImagePath, array $kit): string
    {
        $pad = max(26, (int) round($w * 0.045));
        $xR = $w - $pad;
        $textW = (int) round($w * 0.60);

        $hF = max(20, (int) round($h * 0.155));
        $sF = max(12, (int) round($h * 0.072));
        $cF = max(12, (int) round($h * 0.072));
        $bF = max(11, (int) round($h * 0.060));
        $lF = max(12, (int) round($h * 0.058));

        $gold = $kit['gold'];
        $hFont = $kit['headline_font'];
        $bFont = $kit['body_font'];

        $maxChars = max(8, (int) floor($textW / ($hF * 0.5)));
        $headlineLines = $this->wrap((string) ($copy['headline'] ?? ''), $maxChars, 2);

        $lineH = (int) round($hF * 1.3);
        $gap = max(6, (int) round($h * 0.05));
        $ctaH = (int) round($cF * 2.1);
        $blockH = count($headlineLines) * $lineH
            + (($copy['subheadline'] ?? '') ? $gap + (int) round($sF * 1.3) : 0)
            + (($copy['cta'] ?? '') ? $gap + $ctaH : 0);
        $top = max($pad + (int) round($bF * 2.4), (int) round(($h - $blockH) / 2));

        $p = [];
        $p[] = sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', $w, $h, $w, $h);
        $p[] = '<defs>';
        $p[] = sprintf('<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>', $kit['accent'], $kit['accent_dark']);
        $p[] = sprintf('<linearGradient id="scrim" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="%1$s" stop-opacity="0.84"/><stop offset="0.55" stop-color="%1$s" stop-opacity="0.45"/><stop offset="1" stop-color="%1$s" stop-opacity="0.05"/></linearGradient>', self::SCRIM);
        $p[] = '<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FCE7A6"/><stop offset="0.5" stop-color="' . $gold . '"/><stop offset="1" stop-color="#C8920F"/></linearGradient>';
        $p[] = '</defs>';

        // Background.
        $dataUri = $baseImagePath ? $this->dataUri($baseImagePath) : null;
        if ($dataUri) {
            $p[] = sprintf('<image href="%s" x="0" y="0" width="%d" height="%d" preserveAspectRatio="xMidYMid slice"/>', $dataUri, $w, $h);
        } else {
            $p[] = sprintf('<rect width="%d" height="%d" fill="url(#bg)"/>', $w, $h);
        }
        $p[] = sprintf('<rect width="%d" height="%d" fill="url(#scrim)"/>', $w, $h);

        // Corner ornaments (gold, subtle) on the text side.
        $p[] = $this->ornament($xR, $pad, -1, -1, $hF, $gold);
        $p[] = $this->ornament($xR, $h - $pad, -1, 1, $hF, $gold);

        // Headline (calligraphic, gold gradient, with a soft dark shadow).
        $y = $top + $hF;
        foreach ($headlineLines as $line) {
            $p[] = sprintf('<text x="%d" y="%d" font-family="%s" font-size="%d" fill="#06222b" fill-opacity="0.45" text-anchor="end">%s</text>', $xR + 2, $y + 3, $hFont, $hF, $this->esc($line));
            $p[] = sprintf('<text x="%d" y="%d" font-family="%s" font-size="%d" fill="url(#gold)" text-anchor="end">%s</text>', $xR, $y, $hFont, $hF, $this->esc($line));
            $y += $lineH;
        }
        // Flourish line under the headline.
        $flY = $y - $lineH + (int) round($hF * 0.35);
        $p[] = sprintf('<rect x="%d" y="%d" width="%d" height="3" rx="1.5" fill="%s" opacity="0.85"/>', $xR - (int) round($textW * 0.5), $flY, (int) round($textW * 0.5), $gold);
        $p[] = sprintf('<circle cx="%d" cy="%d" r="4" fill="%s"/>', $xR - (int) round($textW * 0.5) - 6, $flY + 1, $gold);

        // Subheadline.
        if (($sub = trim((string) ($copy['subheadline'] ?? ''))) !== '') {
            $y += $gap - $lineH + (int) round($sF * 1.3) + (int) round($hF * 0.2);
            $p[] = sprintf('<text x="%d" y="%d" font-family="%s" font-size="%d" fill="#ffffff" fill-opacity="0.92" text-anchor="end">%s</text>', $xR, $y, $bFont, $sF, $this->esc($this->clip($sub, (int) floor($textW / ($sF * 0.5)))));
        }

        // CTA pill.
        if (($cta = trim((string) ($copy['cta'] ?? ''))) !== '') {
            $ctaText = $cta . '  ←';
            $padX = (int) round($cF * 0.95);
            $pillW = (int) round(mb_strlen($ctaText) * $cF * 0.52) + 2 * $padX;
            $pillX = $xR - $pillW;
            $pillY = $y + $gap;
            $p[] = sprintf('<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="url(#gold)"/>', $pillX, $pillY, $pillW, $ctaH, (int) round($ctaH / 2));
            $p[] = sprintf('<text x="%d" y="%d" font-family="%s" font-size="%d" font-weight="700" fill="#10303a" text-anchor="middle">%s</text>', $pillX + (int) round($pillW / 2), $pillY + (int) round($ctaH * 0.66), $bFont, $cF, $this->esc($ctaText));
        }

        // Offer badge (top-right).
        if (($badge = trim((string) ($copy['badge'] ?? ''))) !== '') {
            $padX = (int) round($bF * 0.85);
            $badgeW = (int) round(mb_strlen($badge) * $bF * 0.62) + 2 * $padX;
            $badgeH = (int) round($bF * 2.0);
            $bx = $xR - $badgeW;
            $p[] = sprintf('<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="url(#gold)"/>', $bx, $pad, $badgeW, $badgeH, (int) round($badgeH / 2));
            $p[] = sprintf('<text x="%d" y="%d" font-family="%s" font-size="%d" font-weight="700" fill="#10303a" text-anchor="middle">%s</text>', $bx + (int) round($badgeW / 2), $pad + (int) round($badgeH * 0.68), $bFont, $bF, $this->esc($badge));
        }

        // Logo (bottom-right): real brand logo image if available, else house text.
        $logoUri = $kit['logo_image'] ? $this->remoteDataUri($kit['logo_image']) : null;
        if ($logoUri) {
            $logoH = (int) round($h * 0.14);
            $logoW = (int) round($logoH * 3.2);
            $p[] = sprintf('<image href="%s" x="%d" y="%d" width="%d" height="%d" preserveAspectRatio="xMaxYMax meet"/>', $logoUri, $xR - $logoW, $h - $pad - $logoH, $logoW, $logoH);
        } else {
            $logoY = $h - $pad;
            $dot = (int) round($lF * 0.45);
            $logoW = (int) round(mb_strlen($kit['logo_text']) * $lF * 0.55);
            $p[] = sprintf('<text x="%d" y="%d" font-family="%s" font-size="%d" font-weight="700" fill="#ffffff" fill-opacity="0.95" text-anchor="end">%s</text>', $xR, $logoY, $bFont, $lF, $this->esc($kit['logo_text']));
            $p[] = sprintf('<circle cx="%d" cy="%d" r="%d" fill="%s"/>', $xR - $logoW - $dot - 4, $logoY - (int) round($lF * 0.30), $dot, $gold);
        }

        $p[] = '</svg>';
        return implode('', $p);
    }

    /** A small gold corner bracket; $sx/$sy are direction signs (±1). */
    private function ornament(int $x, int $y, int $sx, int $sy, int $unit, string $gold): string
    {
        $len = (int) round($unit * 0.9);
        $x2 = $x + $sx * $len;
        $y2 = $y + $sy * $len;
        return sprintf(
            '<g stroke="%s" stroke-width="2.5" fill="none" opacity="0.6" stroke-linecap="round">'
            . '<path d="M%d %d L%d %d"/><path d="M%d %d L%d %d"/></g>',
            $gold, $x, $y, $x2, $y, $x, $y, $x, $y2
        );
    }

    private function wrap(string $text, int $maxChars, int $maxLines): array
    {
        $text = trim($text);
        if ($text === '') {
            return [];
        }
        $words = preg_split('/\s+/u', $text);
        $lines = [];
        $cur = '';
        foreach ($words as $word) {
            $try = $cur === '' ? $word : $cur . ' ' . $word;
            if (mb_strlen($try) <= $maxChars || $cur === '') {
                $cur = $try;
            } else {
                $lines[] = $cur;
                $cur = $word;
                if (count($lines) === $maxLines) {
                    break;
                }
            }
        }
        if (count($lines) < $maxLines && $cur !== '') {
            $lines[] = $cur;
        }
        if (count($lines) === $maxLines && mb_strlen($lines[$maxLines - 1]) > $maxChars) {
            $lines[$maxLines - 1] = mb_substr($lines[$maxLines - 1], 0, $maxChars - 1) . '…';
        }
        return array_slice($lines, 0, $maxLines);
    }

    private function clip(string $text, int $maxChars): string
    {
        return mb_strlen($text) > $maxChars ? mb_substr($text, 0, $maxChars - 1) . '…' : $text;
    }

    private function dataUri(string $path): ?string
    {
        if (! is_file($path)) {
            return null;
        }
        $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
        $mime = match ($ext) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            default => 'image/jpeg',
        };
        return 'data:' . $mime . ';base64,' . base64_encode((string) file_get_contents($path));
    }

    private function remoteDataUri(string $url): ?string
    {
        try {
            $resp = Http::timeout(20)->get($url);
            if ($resp->failed()) {
                return null;
            }
            $ext = strtolower(pathinfo(parse_url($url, PHP_URL_PATH) ?: '', PATHINFO_EXTENSION));
            $mime = $ext === 'png' ? 'image/png' : ($ext === 'svg' ? 'image/svg+xml' : ($ext === 'gif' ? 'image/gif' : 'image/jpeg'));
            return 'data:' . $mime . ';base64,' . base64_encode($resp->body());
        } catch (\Throwable $e) {
            return null;
        }
    }

    private function esc(string $s): string
    {
        return htmlspecialchars($s, ENT_QUOTES | ENT_XML1, 'UTF-8');
    }
}
