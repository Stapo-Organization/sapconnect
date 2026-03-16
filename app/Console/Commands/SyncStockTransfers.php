<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\StockTransferService;
use App\Models\User;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Services\SMS\TaqnyatService;
use Illuminate\Support\Facades\Log;

class SyncStockTransfers extends Command
{
    protected $signature = 'sap:sync-stock-transfers {--full : Force full sync ignoring last update date} {--code= : Automation Code to run}';
    protected $description = 'Sync Stock Transfers from SAP and send SMS notifications if updates found.';

    public function handle(StockTransferService $service)
    {
        $code = $this->option('code');

        // Fallback or Validation
        if ($code) {
            $automation = Automation::where('code', $code)->first();
        } else {
            // Try default or fail? Let's check default for backward compat but log warning
            $code = 'sync_stock_transfers';
            $automation = Automation::where('code', $code)->first();
        }

        // Safety check if run manually and disabled
        if ($automation && !$automation->is_active) {
            $this->warn("Note: This automation is currently disabled in settings.");
            // We should arguably still run if called manually via CLI/Button, but check caller?
            // "Run Now" from UI might trigger this. If active is false, scheduler won't run it.
            // If run manually, we might want to allow it.
        }

        $sapDatabase = $automation ? $automation->sap_database : 'PPTC_V5_PROD';
        $service->setDatabase($sapDatabase);

        $this->info('Starting Stock Transfer Sync...');

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running'
            ]);
        }

        try {
            $fullSync = $this->option('full');
            $result = $service->importFromSap($fullSync);

            if (is_array($result)) {
                $dbName = $sapDatabase;
                $msg = "Import Stock Transfers Sync Complete\n{$dbName}\nNew: {$result['new']}, Updated: {$result['updated']}, Skipped: {$result['skipped']}";

                if (!empty($result['details'])) {
                    $msg .= "\n\nDetails:\n" . implode("\n", $result['details']);
                }

                $this->info($msg);
                Log::info("SyncStockTransfers Command: $msg");

                if ($automation) {
                    AutomationLog::create([
                        'automation_id' => $automation->id,
                        'status' => 'success',
                        'message' => $msg,
                    ]);
                    $automation->update(['last_run_status' => 'success']);
                }

                // SMS Logic: Check Automation Setting AND Result AND User Preferences
                if ($automation && $automation->notify_sms && ($result['new'] > 0 || $result['updated'] > 0)) {
                    $smsMsg = $msg;

                    $recipients = User::where('receive_sms_on_stock_transfer_import', true)
                        ->whereNotNull('mobile_number')
                        ->pluck('mobile_number')
                        ->toArray();

                    if (!empty($recipients)) {
                        $this->info("Sending SMS to " . count($recipients) . " recipients.");
                        $smsService = new TaqnyatService();
                        $smsService->sendSms($recipients, $smsMsg);
                    } else {
                        $this->info("No SMS recipients found: Users must have 'Receive SMS' enabled.");
                    }
                }
            } else {
                $this->info("Sync finished with legacy result: $result");
            }

        } catch (\Exception $e) {
            $this->error("Sync Failed: " . $e->getMessage());
            Log::error("SyncStockTransfers Command Failed: " . $e->getMessage());

            if ($automation) {
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
                $automation->update(['last_run_status' => 'failed']);
            }
        }
    }
}
