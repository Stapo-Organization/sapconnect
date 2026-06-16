<?php

namespace App\Console\Commands;

use App\Services\GoodsReceiptService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

/**
 * sapconnect-layer importer: pulls Goods Receipt POs (arrivals + actual cost) from
 * SAP into the sapconnect DB. READ-ONLY against SAP. Zooboxi reads the resulting
 * tables — it never calls SAP directly.
 */
class SyncGoodsReceipts extends Command
{
    protected $signature = 'sap:sync-goods-receipts
        {--full : Ignore the incremental watermark and re-pull from the floor date}
        {--since= : Backfill floor date (Y-m-d), e.g. 2024-01-01}
        {--db=PPTC_V5_PROD : SAP company database to read from}';

    protected $description = 'Import Goods Receipt POs (GRPO: arrivals + purchase cost) from SAP into sapconnect.';

    public function handle(GoodsReceiptService $service): int
    {
        ini_set('memory_limit', '1024M'); // GRPO line payloads are large; scheduler has no -d flag
        $db = (string) $this->option('db');
        $service->setDatabase($db);

        $this->info("Starting Goods Receipt (GRPO) import from {$db}...");

        try {
            $result = $service->importFromSap(
                (bool) $this->option('full'),
                $this->option('since') ?: null,
            );

            $msg = "GRPO import complete [{$result['active_db']}] — new: {$result['new']}, updated: {$result['updated']}, skipped: {$result['skipped']}, lines: {$result['lines']}";
            $this->info($msg);
            Log::info("SyncGoodsReceipts: {$msg}");

            return self::SUCCESS;
        } catch (\Throwable $e) {
            $this->error('GRPO import failed: ' . $e->getMessage());
            Log::error('SyncGoodsReceipts failed: ' . $e->getMessage());

            return self::FAILURE;
        }
    }
}
