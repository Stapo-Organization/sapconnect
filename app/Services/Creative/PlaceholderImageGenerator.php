<?php

namespace App\Services\Creative;

/**
 * Zero-cost driver: produces no AI scene. The BannerCompositor then renders a
 * pure typographic brand background. Default before AI is enabled, and the
 * fallback when generation fails or the daily cap is reached.
 */
class PlaceholderImageGenerator implements ImageGeneratorInterface
{
    public function key(): string
    {
        return 'placeholder';
    }

    public function generate(string $prompt, array $opts = []): ?string
    {
        return null; // no scene → compositor uses its brand-gradient background
    }
}
