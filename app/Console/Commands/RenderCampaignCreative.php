<?php

namespace App\Console\Commands;

use App\Jobs\GenerateAdCreative;
use App\Services\Creative\ImageGeneratorManager;
use App\Services\Marketing\BannerCompositor;
use Illuminate\Console\Command;

/**
 * Renders one campaign's creatives synchronously. Web requests (approve / regenerate / refine)
 * launch this DETACHED so the HUB gets its answer at once and polls for the preview — the
 * server has no fastcgi_finish_request, so dispatchAfterResponse would hold the response
 * for the whole render (~1 min with the motion engine).
 */
class RenderCampaignCreative extends Command
{
    protected $signature = 'marketing:render-creative {campaign : marketing_campaigns.id}';

    protected $description = 'Render the creatives (static + motion) of one campaign now';

    public function handle(ImageGeneratorManager $images, BannerCompositor $compositor): int
    {
        $id = (int) $this->argument('campaign');
        (new GenerateAdCreative($id))->handle($images, $compositor);
        $this->info("rendered campaign {$id}");

        return self::SUCCESS;
    }

    /**
     * Launch the render in the background and return immediately. Falls back to running after the
     * response when a detached process cannot be started.
     */
    public static function background(int $campaignId): void
    {
        $php = (string) config('services.creative.php_binary', 'php');
        $cmd = sprintf('nohup %s %s marketing:render-creative %d > /dev/null 2>&1 &', escapeshellarg($php), escapeshellarg(base_path('artisan')), $campaignId);
        if (function_exists('exec')) {
            try {
                exec($cmd, $out, $code);
                if ($code === 0) {
                    return;
                }
            } catch (\Throwable $e) {
                // fall through
            }
        }
        GenerateAdCreative::dispatchAfterResponse($campaignId);
    }
}
