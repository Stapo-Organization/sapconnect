<?php

namespace App\Console\Commands;

use App\Models\MarketingCampaign;
use Illuminate\Console\Command;

/**
 * Moves approved campaigns through their schedule:
 *  - scheduled → active when starts_at has passed (or is null)
 *  - active/scheduled → ended when ends_at has passed
 * Coupon expiry is bound to the campaign window on the WooCommerce side (the
 * coupon's date_expires = ends_at), so an ended campaign cannot keep discounting.
 */
class CampaignLifecycle extends Command
{
    protected $signature = 'marketing:lifecycle';
    protected $description = 'Activate/expire scheduled marketing campaigns by their window.';

    public function handle(): int
    {
        $now = now();

        $activated = MarketingCampaign::where('status', 'scheduled')
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', $now))
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>=', $now))
            ->update(['status' => 'active', 'updated_at' => $now]);

        $ended = MarketingCampaign::whereIn('status', ['scheduled', 'active'])
            ->whereNotNull('ends_at')->where('ends_at', '<', $now)
            ->update(['status' => 'ended', 'updated_at' => $now]);

        $this->info("Lifecycle: activated {$activated}, ended {$ended}.");
        return self::SUCCESS;
    }
}
