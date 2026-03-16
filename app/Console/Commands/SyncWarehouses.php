<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog; // Corrected Import

class SyncWarehouses extends Command
{
    protected $signature = 'sap:sync-warehouses {--code=} {--full}';
    protected $description = 'Sync Warehouses from SAP';

    public function handle()
    {
        $code = $this->option('code');
        $automation = null;
        if ($code) {
            $automation = Automation::where('code', $code)->first();
        } else {
            $automation = Automation::where('code', 'sync_warehouses')->first();
        }

        $sapDatabase = $automation ? $automation->sap_database : 'PPTC_V5_PROD';

        $this->info("Starting Warehouses Sync for $sapDatabase...");

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running'
            ]);
        }

        try {
            // Actual Logic Placeholder
            sleep(1);
            $msg = "Warehouses Sync Completed (Placeholder for $sapDatabase).";
            $this->info($msg);

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'success',
                    'message' => $msg,
                ]);
            }
        } catch (\Exception $e) {
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
            }
            $this->error($e->getMessage());
        }
    }
}
