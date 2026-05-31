<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\SapCreditMemo;
use App\Models\SapCreditMemoLine;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;

class SyncCreditMemos extends Command
{
    protected $signature = 'sap:sync-credit-memos';
    protected $description = 'Sync all historical SAP Credit Memos (Returns)';

    public function handle()
    {
        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }
        
        $this->info("Starting ALL Credit Memos Sync...");

        try {
            $sapClient = app(\App\Services\SAP\SapClient::class);
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            $skip = 0;
            $totalFetched = 0;
            
            while (true) {
                $response = $sapClient->get('CreditNotes', [
                    '$top' => 100,
                    '$skip' => $skip,
                    '$orderby' => 'DocEntry asc'
                ]);

                $memos = $response['value'] ?? [];
                if (empty($memos)) {
                    break;
                }

                $fetchedCount = count($memos);
                DB::beginTransaction();
                foreach ($memos as $memo) {
                     $sapMemo = SapCreditMemo::updateOrCreate(
                        ['doc_num' => $memo['DocNum']],
                        [
                            'card_code' => $memo['CardCode'] ?? null,
                            'doc_date' => $memo['DocDate'] ?? null,
                            'sales_employee_code' => $memo['SalesPersonCode'] ?? null,
                            'doc_total' => $memo['DocTotal'] ?? 0,
                        ]
                    );

                    if (isset($memo['DocumentLines']) && is_array($memo['DocumentLines'])) {
                        foreach ($memo['DocumentLines'] as $line) {
                            if (!empty($line['ItemCode'])) {
                                SapCreditMemoLine::updateOrCreate(
                                    [
                                        'sap_credit_memo_id' => $sapMemo->id,
                                        'item_code' => $line['ItemCode'],
                                    ],
                                    [
                                        'warehouse_code' => $line['WarehouseCode'] ?? null,
                                        'item_description' => $line['ItemDescription'] ?? null,
                                        'quantity' => $line['Quantity'] ?? 0,
                                        'price' => $line['Price'] ?? 0,
                                    ]
                                );
                            }
                        }
                    }
                }
                DB::commit();

                $skip += $fetchedCount;
                $totalFetched += $fetchedCount;
                $this->info("Fetched $totalFetched records...");
                usleep(300000); // 0.3s delay
            }

            $msg = "Successfully synced {$totalFetched} total credit memos from PPTC_V5_PROD.";
            $this->info($msg);
            
            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
        } catch (\Exception $e) {
            $msg = "Error syncing all credit memos: " . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        }
    }
}
