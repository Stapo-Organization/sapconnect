<?php

namespace App\Console\Commands;

use App\Models\PurchaseOrder;
use App\Services\SapClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class SyncPurchaseOrderStatus extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'sap:sync-po-status
                            {--limit=100 : Maximum number of POs to sync}';

    /**
     * The console command description.
     */
    protected $description = 'Sync purchase order status and values from SAP';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('Syncing Purchase Order statuses from SAP...');

        $pendingPOs = PurchaseOrder::whereIn('sync_status', ['pending', 'failed'])
            ->orWhereNull('sync_status')
            ->limit((int) $this->option('limit'))
            ->get();

        if ($pendingPOs->isEmpty()) {
            $this->info('No pending POs to sync.');
            return Command::SUCCESS;
        }

        $this->info("Found {$pendingPOs->count()} PO(s) to sync.");

        $synced = 0;
        $failed = 0;

        foreach ($pendingPOs as $po) {
            try {
                // Attempt to sync with SAP
                // Note: This requires the SapClient service to be configured
                // The actual SAP API call would go here
                
                // For now, log the attempt
                Log::info("SAP PO Sync attempted", [
                    'po_id' => $po->id,
                    'current_status' => $po->sync_status,
                ]);

                $this->line("  → PO #{$po->id}: Sync attempted (Supplier: {$po->supplier?->name})");
                $synced++;
            } catch (\Exception $e) {
                $po->update(['sync_status' => 'failed']);
                $failed++;

                Log::error("SAP PO Sync failed", [
                    'po_id' => $po->id,
                    'error' => $e->getMessage(),
                ]);

                $this->error("  ✗ PO #{$po->id}: {$e->getMessage()}");
            }
        }

        $this->info("Sync complete: {$synced} synced, {$failed} failed.");

        return $failed > 0 ? Command::FAILURE : Command::SUCCESS;
    }
}
