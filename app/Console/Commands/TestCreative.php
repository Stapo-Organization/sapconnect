<?php

namespace App\Console\Commands;

use App\Services\Creative\ImageGeneratorManager;
use App\Services\Marketing\BannerCompositor;
use Illuminate\Console\Command;

/**
 * Spike / smoke test for the creative pipeline:
 *   php artisan marketing:test-creative --format=hero
 * Generates an AI visual base (or placeholder) and composites a sample Arabic
 * banner, printing the saved PNG path. Proves Replicate + Chrome Arabic shaping.
 */
class TestCreative extends Command
{
    protected $signature = 'marketing:test-creative
        {--driver= : replicate|placeholder (defaults to config)}
        {--format=hero : hero|wide|card|strip}
        {--prompt= : override the visual prompt}
        {--product= : optional product image URL to composite}';

    protected $description = 'Generate one sample ad banner end-to-end (AI base + Arabic compositor).';

    public function handle(ImageGeneratorManager $images, BannerCompositor $compositor): int
    {
        $format = (string) $this->option('format');
        [, , $aspect] = BannerCompositor::FORMATS[$format] ?? BannerCompositor::FORMATS['hero'];

        $driver = $images->driver($this->option('driver') ?: null);
        $this->info("Driver: {$driver->key()} · format: {$format} · aspect: {$aspect}");

        $prompt = (string) ($this->option('prompt')
            ?: 'premium e-commerce hero banner background for a pet & home goods store, '
            . 'soft studio gradient, warm teal and gold bokeh light, clean empty area on the right '
            . 'for text, modern minimal, photographic, high quality, no text');

        $images = $this->option('product') ? [(string) $this->option('product')] : [];
        $this->line($images ? 'Generating scene with product (nano-banana)...' : 'Generating scene (txt2img)...');
        $base = $driver->generate($prompt, ['image_inputs' => $images, 'aspect_ratio' => $aspect]);
        $this->line($base ? "  base: {$base}" : '  base: (none — using brand gradient)');

        $this->line('Compositing Arabic banner...');
        $png = $compositor->render(
            $format,
            [
                'headline' => 'وصل حديثاً — تشكيلة العناية بالحيوان',
                'subheadline' => 'متوفّر الآن في فرعك · توصيل خلال ساعتين',
                'cta' => 'تسوّق الآن',
                'badge' => 'الأكثر طلباً',
            ],
            $base,
            null, // product is already in the scene
        );

        if (! $png) {
            $this->error('Compositor failed — check logs.');
            return self::FAILURE;
        }

        $this->newLine();
        $this->info('✅ Banner saved: ' . $png);
        $this->line('size: ' . number_format(filesize($png) / 1024, 1) . ' KB');

        return self::SUCCESS;
    }
}
