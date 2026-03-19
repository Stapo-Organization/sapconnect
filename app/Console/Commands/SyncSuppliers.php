<?php

namespace App\Console\Commands;

use App\Models\Supplier;
use App\Services\SAP\SapClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class SyncSuppliers extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'sap:sync-suppliers {--code=} {--full}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Sync Suppliers (Business Partners) from SAP based on active environment.';

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

        $this->info("Starting Suppliers Sync for Active Database: $sapDatabase");

        try {
            $page = 1;
            $count = 0;
            $pageSize = 100;
            $skip = 0;

            do {
                $this->info("  Fetching page $page... (Skip: $skip)");

                // Explicit pagination with sorting
                $response = $this->sap->get('BusinessPartners', [
                    '$filter' => "CardType eq 'cSupplier'",
                    '$orderby' => 'CardCode',
                    '$select' => 'CardCode,CardName,Currency,CreditLimit,OpenOrdersBalance,CurrentAccountBalance',
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
                    $sapCode = $item['CardCode'];
                    // Fallback to SAR if currency is null or '##' (SAP's local currency symbol sometimes)
                    $currency = (empty($item['Currency']) || $item['Currency'] == '##') ? 'SAR' : $item['Currency'];
                    
                    $data = [
                        'name' => $item['CardName'],
                        'currency' => $currency,
                        'credit_limit' => $item['CreditLimit'] ?? 0,
                        'open_po_value' => $item['OpenOrdersBalance'] ?? 0,
                        'achieved_amount' => $item['CurrentAccountBalance'] ?? 0,
                    ];

                    Supplier::updateOrCreate(
                        ['sap_code' => $sapCode],
                        $data
                    );
                    $count++;
                }

                if ($fetchedCount === 0) {
                    break;
                }

                $skip += $fetchedCount;
                $page++;

            } while (true);

            $msg = "Suppliers Sync Completed. Processed $count records from $sapDatabase.";
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
            Log::error("Suppliers Sync Failed [$sapDatabase]: " . $e->getMessage());

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
