<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Services\ShipGo\ShipGoSapService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Mirrors the customers of the ShipGo SAP company into `shipgo_customers`.
 * READ-ONLY toward SAP (Service Layer GET only).
 */
class SyncShipGoCustomers extends Command
{
    protected $signature   = 'shipgo:sync-customers';
    protected $description = 'Sync ShipGo (SHIPGO_LIVE_V1) customers from SAP into the local mirror (read-only)';

    protected function service(): ShipGoSapService
    {
        return app(ShipGoSapService::class);
    }

    protected function label(): string
    {
        return 'ShipGo';
    }

    public function handle(): int
    {
        $sap = $this->service();
        $automation = Automation::where('command_signature', $this->signature)->first();
        $automation?->update(['last_run_at' => now(), 'last_run_status' => 'running']);

        $this->info("Syncing {$this->label()} customers from {$sap->companyDb()}...");
        DB::disableQueryLog();

        try {
            $result = $sap->syncCustomers();
            $msg = "{$this->label()} customers synced from {$sap->companyDb()}: {$result['total']} read, {$result['created']} new, {$result['updated']} updated.";
            $this->info($msg);
            $automation?->update(['last_run_status' => 'success']);
            if ($automation) {
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
            return self::SUCCESS;
        } catch (\Throwable $e) {
            $msg = "Error syncing {$this->label()} customers: " . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            $automation?->update(['last_run_status' => 'failed']);
            if ($automation) {
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
            return self::FAILURE;
        }
    }
}
