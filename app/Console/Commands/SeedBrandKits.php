<?php

namespace App\Console\Commands;

use App\Models\BrandDesignKitModel;
use Illuminate\Console\Command;

/**
 * Imports researched per-brand advertising kits into brand_design_kits.
 * Idempotent: upserts by brand_key, so re-running with an updated JSON refreshes
 * the kits in place. Reads a JSON array of kit objects (see database/data/
 * brand_kits.json). Used both locally and on prod after research lands.
 */
class SeedBrandKits extends Command
{
    protected $signature = 'marketing:seed-brand-kits
        {--file=database/data/brand_kits.json : Path to the kits JSON (array of objects)}
        {--dry : Parse and report without writing}';

    protected $description = 'Upsert per-brand advertising design kits from a researched JSON file';

    /** Columns we accept from each JSON object. */
    private const FIELDS = [
        'brand_name', 'country', 'founded', 'category', 'positioning',
        'tagline_en', 'tagline_ar', 'audience_ar',
        'imagery_style', 'imagery_notes',
        'accent', 'accent_dark', 'gold', 'palette_notes',
        'headline_font', 'body_font', 'text_style_ar', 'mood_ar', 'do_not_ar',
        'scene_style', 'confidence', 'sources', 'logo_url',
    ];

    public function handle(): int
    {
        $path = $this->option('file');
        $abs = str_starts_with($path, '/') ? $path : base_path($path);

        if (! is_file($abs)) {
            $this->error("File not found: {$abs}");
            return self::FAILURE;
        }

        $data = json_decode((string) file_get_contents($abs), true);
        if (! is_array($data)) {
            $this->error('JSON did not decode to an array.');
            return self::FAILURE;
        }

        $created = 0;
        $updated = 0;
        $skipped = 0;

        foreach ($data as $row) {
            $key = $row['brand_key'] ?? null;
            if (! $key) {
                $skipped++;
                continue;
            }

            $attrs = ['is_active' => true];
            foreach (self::FIELDS as $f) {
                if (array_key_exists($f, $row) && $row[$f] !== null && $row[$f] !== '') {
                    $attrs[$f] = $row[$f];
                }
            }

            if ($this->option('dry')) {
                $this->line(sprintf('  %s — %s [%s, %s, %s]',
                    $key,
                    $attrs['brand_name'] ?? '?',
                    $attrs['imagery_style'] ?? '-',
                    $attrs['accent'] ?? '-',
                    $attrs['confidence'] ?? '-',
                ));
                continue;
            }

            $existing = BrandDesignKitModel::where('brand_key', (string) $key)->first();
            if ($existing) {
                $existing->update($attrs);
                $updated++;
            } else {
                BrandDesignKitModel::create(array_merge(['brand_key' => (string) $key], $attrs));
                $created++;
            }
        }

        if ($this->option('dry')) {
            $this->info(sprintf('Dry run: %d kit(s) in file, %d without brand_key.', count($data) - $skipped, $skipped));
            return self::SUCCESS;
        }

        $this->info(sprintf('Brand kits seeded — created %d, updated %d, skipped %d.', $created, $updated, $skipped));
        return self::SUCCESS;
    }
}
