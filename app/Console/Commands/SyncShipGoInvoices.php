<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Services\ShipGo\ShipGoSapService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Mirrors A/R invoice headers of the ShipGo SAP company into `shipgo_invoices`.
 * Incremental by SAP UpdateDate; --full re-reads everything. GET only.
 */
class SyncShipGoInvoices extends Command
{
    protected $signature   = 'shipgo:sync-invoices {--full : Re-read every invoice instead of recent changes}';
    protected $description = 'Sync ShipGo (SHIPGO_LIVE_V1) A/R invoice headers from SAP (read-only)';

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
        @ini_set('memory_limit', '1024M');
        DB::disableQueryLog();

        $sap        = $this->service();
        $automation = Automation::where('command_signature', 'like', explode(' ', $this->signature)[0] . '%')->first();
        $automation?->update(['last_run_at' => now(), 'last_run_status' => 'running']);

        try {
            $r   = $sap->syncInvoices((bool) $this->option('full'));
            $msg = "{$this->label()} invoices synced from {$sap->companyDb()}: {$r['total']} read, {$r['created']} new, {$r['updated']} updated.";
            $this->info($msg);
            $automation?->update(['last_run_status' => 'success']);
            if ($automation) {
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
            return self::SUCCESS;
        } catch (\Throwable $e) {
            $msg = "Error syncing {$this->label()} invoices: " . $e->getMessage();
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
