<?php

namespace App\Services\Creative;

/**
 * Resolves the active image-generation driver. Configured via
 * config('services.creative.driver') ('gpt-image' | 'replicate' | 'placeholder').
 */
class ImageGeneratorManager
{
    public function driver(?string $name = null): ImageGeneratorInterface
    {
        $name ??= (string) config('services.creative.driver', 'placeholder');

        return match ($name) {
            'gpt-image' => new GptImageGenerator(),
            'replicate' => new ReplicateImageGenerator(),
            'placeholder' => new PlaceholderImageGenerator(),
            default => new PlaceholderImageGenerator(),
        };
    }
}
