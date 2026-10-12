<?php

namespace App\Console\Commands;

use App\Services\Zooboxi\CatalogGateService;
use Illuminate\Console\Command;

/**
 * بوابة كتالوج زوبوكسي — scheduled every 15 minutes (after the SAP stock
 * mirror refreshes). Activates ready products, holds the rest with reasons.
 */
class ZooboxiCatalogGate extends Command
{
    protected $signature = 'zooboxi:catalog-gate
                            {--dry-run : Evaluate and report, write nothing}
                            {--limit= : Products per run (default services.zooboxi_gate.batch)}
                            {--item=* : Only these item codes}
                            {--force : Ignore the stock rule for the given items}';

    protected $description = 'Activate production items on the Zooboxi store when ready; hold the rest with reasons';

    public function handle(CatalogGateService $gate): int
    {
        if (!config('services.zooboxi_gate.enabled', true) && !$this->option('dry-run')) {
            $this->warn('ZOOBOXI_GATE_ENABLED=false — nothing done.');
            return self::SUCCESS;
        }

        $items = array_filter((array) $this->option('item'));
        $limit = (int) ($this->option('limit') ?: config('services.zooboxi_gate.batch', 150));
        $summary = $gate->run(
            dryRun: (bool) $this->option('dry-run'),
            limit: $limit,
            itemCodes: $items ?: null,
            force: (bool) $this->option('force') && !empty($items),
        );

        $this->info(sprintf('checked=%d activated=%d held=%d errors=%d%s',
            $summary['checked'], $summary['activated'], $summary['held'], $summary['errors'],
            $this->option('dry-run') ? ' (dry-run)' : ''));

        if ($this->getOutput()->isVerbose() || $this->option('dry-run')) {
            foreach ($summary['items'] as $it) {
                $this->line(sprintf('  %-14s %-10s %s', $it['item_code'], $it['result'],
                    implode(',', $it['reasons'] ?? []) . ($it['error'] ?? '')));
            }
        }
        return $summary['errors'] > 0 ? self::FAILURE : self::SUCCESS;
    }
}
