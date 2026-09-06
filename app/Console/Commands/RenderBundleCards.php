<?php

namespace App\Console\Commands;

use App\Models\ProductBundle;
use App\Services\Marketing\BundleCardComposer;
use Illuminate\Console\Command;

/**
 * Compose the collage card image for approved/live bundles that don't have
 * one yet (--all re-renders everything, e.g. after a design change). The
 * store's hourly pull picks the URL up and sets it as the product thumbnail.
 */
class RenderBundleCards extends Command
{
    protected $signature = 'marketing:render-bundle-cards {--all : Re-render even bundles that already have a card} {--id= : One bundle only}';

    protected $description = 'Compose Mowkly-style collage card images for approved/live bundles';

    public function handle(BundleCardComposer $composer): int
    {
        $query = ProductBundle::with('items')
            ->whereIn('status', [ProductBundle::STATUS_APPROVED, ProductBundle::STATUS_LIVE]);

        if ($this->option('id')) {
            $query = ProductBundle::with('items')->whereKey((int) $this->option('id'));
        } elseif (! $this->option('all')) {
            $query->whereNull('image_url');
        }

        $done = 0;
        $failed = 0;
        foreach ($query->get() as $bundle) {
            $url = $composer->render($bundle);
            if ($url !== null) {
                $bundle->update(['image_url' => $url]);
                $this->line("#{$bundle->id} → {$url}");
                $done++;
            } else {
                $this->warn("#{$bundle->id} — no card (missing photos?)");
                $failed++;
            }
        }

        $this->info("cards: rendered={$done} failed={$failed}");

        return self::SUCCESS;
    }
}
