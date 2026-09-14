<?php

namespace App\Console\Commands;

use App\Services\Marketing\HeroArtGenerator;
use Illuminate\Console\Command;

/**
 * Draw the app slider's artwork.
 *
 * Costs real money per image (gpt-image-2), so it is not scheduled hourly:
 * weekly is plenty for evergreen scenes, and `--theme=` re-rolls a single one
 * when the owner does not like it.
 */
class GenerateHeroArt extends Command
{
    protected $signature = 'marketing:hero-art
        {--theme=* : Only these themes (express_clock, express_top, express_new, cutoff, bundles, clearance)}
        {--refresh-manifest : Rewrite the manifest from the images already on disk — generates nothing, costs nothing}
        {--needs : Only the need tiles\' and the home products\' cut-outs (the slides are left alone)}
        {--catalog : Only the shelf-wide catalogue cut-outs, keyed by SAP code (incremental)}';

    protected $description = 'Generate the AI artwork behind the app home slider';

    public function handle(HeroArtGenerator $art): int
    {
        // Dozens of packshots decoded and flood-filled in one process: the
        // web default is too tight for an image job, and this is a cron.
        ini_set('memory_limit', '512M');

        if ($this->option('refresh-manifest')) {
            $urls = $art->refreshManifest(fn (string $line) => $this->line("  {$line}"));
            $this->info(count($urls) . ' image(s) re-listed');
            return self::SUCCESS;
        }

        $themes = array_values(array_filter((array) $this->option('theme')));
        $made = [];
        if (! $this->option('needs') && ! $this->option('catalog')) {
            $this->info($themes === [] ? 'Generating every slide…' : 'Generating: ' . implode(', ', $themes));
            $made = $art->run($themes, fn (string $line) => $this->line("  {$line}"));
        }

        // The need tiles ride along with a full run, or alone on --needs;
        // a run pinned to particular slides leaves them be.
        $needs = [];
        $codes = [];
        if ($this->option('catalog')) {
            $this->info('Cutting every product on the express shelves…');
            $codes = $art->catalog(fn (string $line) => $this->line("  {$line}"));
        } elseif ($this->option('needs') || $themes === []) {
            $this->info('Cutting the need tiles\' products…');
            $needs = $art->needs(fn (string $line) => $this->line("  {$line}"));
            $this->info('Cutting the home\'s own products…');
            $art->products(fn (string $line) => $this->line("  {$line}"));
            if ($themes === []) {
                $this->info('Cutting every product on the express shelves…');
                $codes = $art->catalog(fn (string $line) => $this->line("  {$line}"));
            }
        }

        if ($made === [] && $needs === [] && $codes === []) {
            $this->warn('nothing was generated');
            return self::FAILURE;
        }

        $tiles = array_sum(array_map('count', $needs));
        $this->info(count($made) . ' slide(s), ' . $tiles . ' need tile(s) — manifest updated');
        return self::SUCCESS;
    }
}
