<?php

namespace App\Services\Creative;

/**
 * Produces the VISUAL SCENE of an ad creative — never Arabic text (that is
 * composited later by App\Services\Marketing\BannerCompositor). Swappable driver.
 *
 * When product image URLs are supplied, the driver uses an image-to-image model
 * (e.g. nano-banana) to place the REAL product into a premium scene; otherwise a
 * text-to-image model (e.g. Imagen 4 Ultra) renders a product-free scene.
 */
interface ImageGeneratorInterface
{
    /** Stable driver key, e.g. "replicate" / "placeholder". */
    public function key(): string;

    /**
     * Generate the scene image and return its ABSOLUTE local file path, or null on
     * failure (the compositor then falls back to a pure CSS brand background).
     *
     * @param string $prompt Visual-only prompt (no text rendering).
     * @param array{image_inputs?:array<int,string>,aspect_ratio?:string,seed?:int} $opts
     */
    public function generate(string $prompt, array $opts = []): ?string;
}
