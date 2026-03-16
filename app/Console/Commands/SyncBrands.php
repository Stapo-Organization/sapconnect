<?php

namespace App\Console\Commands;

use App\Models\Brand;
use App\Models\BrandTest;
use App\Services\SAP\SapClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;

class SyncBrands extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'sap:sync-brands {--code=} {--full}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Sync ItemGroups (Brands) from SAP based on active environment.';

    protected $sap;

    /**
     * Execute the console command.
     */
    public function handle(SapClient $sap)
    {
        $this->sap = $sap;

        // 1. Resolve Automation Context
        $code = $this->option('code');
        $automation = null;

        if ($code) {
            $automation = \App\Models\Automation::where('code', $code)->first();
        }

        // If no automation found but running via manual command without code, try default? 
        // Or just rely on arguments.
        // For robustness, if automation is found, use its DB.

        $sapDatabase = $automation ? $automation->sap_database : 'PPTC_V5_PROD';

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running',
            ]);
            // Force SAP Config to match Automation Setting
            $this->sap->setCompanyDb($sapDatabase);
        } else {
            // Fallback to session or config if running manually without automation record
            $activeDb = session('sap_company_db', 'PPTC_V5_PROD');
            $this->sap->setCompanyDb($activeDb);
            $sapDatabase = $activeDb;
        }

        $this->info("Starting Brands Sync for Active Database: $sapDatabase");

        $this->info("Detected Environment: PRODUCTION -> Syncing to 'brands' table.");

        try {
            $page = 1;
            $count = 0;
            $pageSize = 100;
            $skip = 0;

            do {
                $this->info("  Fetching page $page... (Skip: $skip)");

                // Explicit pagination with sorting
                $response = $this->sap->get('ItemGroups', [
                    '$orderby' => 'Number',
                    '$top' => $pageSize,
                    '$skip' => $skip
                ]);

                $items = $response['value'] ?? [];

                if (empty($items)) {
                    break;
                }

                $fetchedCount = count($items);
                $this->info("    - Retrieved $fetchedCount records.");

                foreach ($items as $item) {
                    $envSource = 'production';
                    $data = [
                        'code' => $item['Number'],
                        'name' => $item['GroupName'],
                        'source' => $envSource,
                    ];

                    Brand::updateOrCreate(
                        ['code' => $data['code']],
                        ['name' => $data['name'], 'source' => $data['source']]
                    );
                    $count++;
                }

                if ($fetchedCount === 0) {
                    break;
                }

                $skip += $fetchedCount;
                $page++;

            } while (true);

            $msg = "Brands Sync Completed. Processed $count records from $sapDatabase.";
            $this->info($msg);

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                \App\Models\AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'success',
                    'message' => $msg,
                ]);
            }

        } catch (\Exception $e) {
            $this->error("Failed to sync: " . $e->getMessage());
            Log::error("Brands Sync Failed [$sapDatabase]: " . $e->getMessage());

            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                \App\Models\AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
            }
        }
    }
}
