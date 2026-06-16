<?php

namespace App\Services\Marketing;

use App\Models\MarketingCampaign;

/**
 * Builds the full gpt-image-2 creative prompt for one banner — the recipe distilled
 * from the validated brand samples: brand scene art-direction + imagery style
 * (real photo / illustration / hybrid) + real products (kept identical) + brand
 * logo/wordmark + correctly-shaped Arabic ad copy + species-correct subject.
 * The model renders the finished banner; no resvg compositing afterwards.
 */
class AdPromptBuilder
{
    /** gpt-image-2 aspect ratio per store format (only 1:1 / 3:2 / 2:3 are supported). */
    public const ASPECT = ['card' => '1:1', 'hero' => '3:2', 'wide' => '3:2', 'strip' => '3:2'];

    public function aspectFor(string $format): string
    {
        return self::ASPECT[$format] ?? '3:2';
    }

    /**
     * @param array<string,mixed> $kit resolved BrandDesignKit
     * @param array{product_count:int,has_logo:bool,species_scene:string,brand_name:string} $ctx
     */
    public function build(MarketingCampaign $campaign, array $kit, string $format, array $ctx): string
    {
        $scene = $kit['scene_style'] ?? 'premium e-commerce advertising scene, elegant studio lighting';
        $accent = $kit['accent'] ?? '#0d9488';
        $gold = $kit['gold'] ?? '#F4BE2C';
        $brand = $ctx['brand_name'] ?: 'منتجات';
        $animal = $ctx['species_scene'] ?: 'a happy pet';

        $logo = $ctx['has_logo']
            ? "Place the provided brand logo (the LAST input image) {$this->logoProminence($format)} — use it exactly as given, do not redraw or restyle it."
            : "Render the brand wordmark \"{$brand}\" {$this->logoProminence($format)}, in a style that matches the brand identity.";

        $parts = array_filter([
            $this->canvasLine($format),
            $this->layout($format, (int) $ctx['product_count']),
            "Scene art-direction: {$scene}. Use the brand accent color {$accent} and highlight {$gold} in the banner blocks.",
            $this->imageryDirection($kit['imagery_style'] ?? 'photographic'),
            "Feature {$animal}, matching the products' species — never show an animal of a different species than the products.",
            $logo,
            $this->textBlock($campaign),
            'Polished, professional e-commerce advertising. The products must be IDENTICAL to the reference images — do not alter packaging or invent any product label text. Every Arabic word must be spelled and shaped perfectly; no extra, repeated or garbled text.',
            ! empty($kit['do_not_ar']) ? ('Avoid (brand do-nots): ' . $kit['do_not_ar']) : null,
            // Owner's revision note takes priority — apply it precisely while keeping the brand identity.
            ! empty($campaign->refinement_note)
                ? ('IMPORTANT owner revision note — apply this precisely while keeping the brand identity and the exact Arabic copy above: ' . $campaign->refinement_note)
                : null,
        ]);

        return implode(' ', $parts);
    }

    /**
     * Brand boutique-page prompt (campaigns carrying a brand_code): the banner sells
     * the WHOLE brand world — its logo, palette, scene mood and signature imagery —
     * rather than one product. Products, when supplied, are premium supporting props.
     * Used for the brand hero (3:2) and the square promo tiles (1:1).
     *
     * @param array<string,mixed> $kit resolved BrandDesignKit (forBrand)
     * @param array{product_count:int,has_logo:bool,species_scene:string,brand_name:string} $ctx
     */
    public function buildBrandPage(MarketingCampaign $campaign, array $kit, string $format, array $ctx): string
    {
        $scene = $kit['scene_style'] ?? 'premium brand storefront scene, elegant studio lighting';
        $accent = $kit['accent'] ?? '#0d9488';
        $gold = $kit['gold'] ?? '#F4BE2C';
        $palette = trim((string) ($kit['palette_notes'] ?? ''));
        $brand = $ctx['brand_name'] ?: 'العلامة';
        $animal = $ctx['species_scene'] ?: 'a happy pet';
        $count = (int) $ctx['product_count'];

        $logo = $ctx['has_logo']
            ? "Place the provided brand logo (the LAST input image) {$this->logoProminence($format)} — use it exactly as given, do not redraw or restyle it."
            : "Render the brand wordmark \"{$brand}\" {$this->logoProminence($format)}, in a style that matches the brand identity.";

        $layout = $format === 'card'
            ? ($count > 0
                ? 'Single-tile layout: ONE of the provided products as a clean, appetizing hero, centered, with tasteful negative space.'
                : 'Single-tile layout: a clean brand-world vignette (a signature ingredient / texture) with tasteful negative space.')
            : ($count > 0
                ? "Brand-world layout: arrange the {$count} provided products as a neat premium group on one side, leaving the other side calm for the brand logo and text."
                : 'Brand-world layout: a premium brand vignette on one side, leaving the other side calm and clear for the brand logo and text.');

        $species = $count > 0
            ? "Feature {$animal}, matching the products' species — never show an animal of a different species than the products."
            : "You may feature {$animal} subtly, matching the brand's category, but keep the brand identity the hero.";

        $parts = array_filter([
            $this->canvasLine($format),
            "Premium BRAND STOREFRONT banner for the brand «{$brand}» — it must feel like the brand's own flagship boutique, not a single-product ad.",
            $layout,
            "Scene art-direction: {$scene}. Build the ENTIRE banner in the brand's palette — accent {$accent}, highlight {$gold}." . ($palette !== '' ? " Palette notes: {$palette}." : ''),
            $this->imageryDirection($kit['imagery_style'] ?? 'photographic'),
            $species,
            $logo,
            $this->textBlock($campaign),
            'Polished, professional brand-identity advertising. Any provided products must be IDENTICAL to the reference images — do not alter packaging or invent product label text. Every Arabic word must be spelled and shaped perfectly; no extra, repeated or garbled text.',
            ! empty($kit['do_not_ar']) ? ('Avoid (brand do-nots): ' . $kit['do_not_ar']) : null,
            ! empty($campaign->refinement_note)
                ? ('IMPORTANT owner revision note — apply this precisely while keeping the brand identity and the exact Arabic copy above: ' . $campaign->refinement_note)
                : null,
        ]);

        return implode(' ', $parts);
    }

    private function canvasLine(string $format): string
    {
        return $format === 'card'
            ? 'Square (1:1) advertising banner.'
            : 'Landscape (3:2) advertising banner.';
    }

    private function layout(string $format, int $count): string
    {
        if ($format === 'card') {
            return 'Single-product layout: the primary product as a clean, well-lit hero, centered with tasteful negative space.';
        }
        if ($count > 1) {
            return "Bundle/brand layout: arrange the {$count} provided products together as a neat, premium group on one side, leaving the other side calm and clear for the text.";
        }
        return 'Hero layout: the product as a confident hero on one side, with calm clear space on the other side for the text.';
    }

    private function logoProminence(string $format): string
    {
        return $format === 'card'
            ? 'small and tasteful in a top corner'
            : 'prominently and large at the top as the clear focal brand mark';
    }

    /** Turn imagery_style into an explicit art-direction clause. */
    private function imageryDirection(string $imageryStyle): string
    {
        return match ($imageryStyle) {
            'illustration' => 'Use a clean, modern flat illustration / graphic style — NO photorealism, no real animals.',
            'hybrid' => 'Combine the real product photographs with subtle illustrated brand motifs and graphic accents.',
            default => 'Use REAL professional product photography — no cartoon, no illustration; real subjects, soft natural studio lighting, subtle reflections, a cozy tasteful background.',
        };
    }

    /** The Arabic copy to render, only including the parts the campaign actually set. */
    private function textBlock(MarketingCampaign $campaign): string
    {
        $headline = trim((string) $campaign->headline_ar);
        $sub = trim((string) $campaign->subheadline_ar);
        $cta = trim((string) $campaign->cta_ar);
        $badge = trim((string) $campaign->badge_ar);

        $bits = ['Render this Arabic text, large and perfectly legible:'];
        if ($headline !== '') {
            $bits[] = "a bold headline «{$headline}»";
        }
        if ($sub !== '') {
            $bits[] = "a smaller subtitle «{$sub}»";
        }
        if ($cta !== '') {
            $bits[] = "and a clear call-to-action pill button «{$cta}»";
        }
        $line = implode(', ', $bits) . '.';
        if ($badge !== '') {
            $line .= " Add a small corner badge «{$badge}».";
        }
        $line .= ' All text in clean, modern Arabic typography, right-to-left, correctly shaped.';
        return $line;
    }
}
