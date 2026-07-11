<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\SapCreditMemo;
use App\Models\SapCreditMemoLine;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class SyncRecentCreditMemos extends Command
{
    protected $signature = 'sap:sync-recent-credit-memos';
    protected $description = 'Sync recent SAP Credit Memos (Returns) for the last 3 days';

    public function handle()
    {
        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }
        
        $this->info("Starting Recent Credit Memos Sync...");

        try {
            $sapClient = app(\App\Services\SAP\SapClient::class);
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            // Sync the last 3 days
            $startDate = Carbon::today()->subDays(2)->toDateString();
            
            $skip = 0;
            $totalFetched = 0;
            
            while (true) {
                // Returns in retail POS are typically logged as CreditNotes
                $response = $sapClient->get('CreditNotes', [
                    '$filter' => "DocDate ge '{$startDate}' and Cancelled eq 'tNO'",
                    '$top' => 50,
                    '$skip' => $skip,
                    '$orderby' => 'DocEntry desc'
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
                            'cancelled' => $memo['Cancelled'] === 'tYES' ? 'Y' : 'N',
                        ]
                    );

                    // Delete old lines and re-insert to avoid key collision
                    $sapMemo->lines()->delete();

                    if (isset($memo['DocumentLines']) && is_array($memo['DocumentLines'])) {
                        foreach ($memo['DocumentLines'] as $line) {
                            if (!empty($line['ItemCode'])) {
                                SapCreditMemoLine::create([
                                    'sap_credit_memo_id' => $sapMemo->id,
                                    'line_num' => $line['LineNum'] ?? null,
                                    'item_code' => $line['ItemCode'],
                                    'warehouse_code' => $line['WarehouseCode'] ?? null,
                                    'ocr_code' => $line['CostingCode'] ?? null,
                                    'item_description' => $line['ItemDescription'] ?? null,
                                    'quantity' => $line['Quantity'] ?? 0,
                                    'price' => $line['Price'] ?? 0,
                                    // SAP actual economics (ex-VAT) — a return's true profit reversal.
                                    'line_revenue' => $line['LineTotal'] ?? null,
                                    'gross_profit' => $line['GrossProfit'] ?? null,
                                ]);
                            }
                        }
                    }
                }
                DB::commit();

                $skip += $fetchedCount;
                $totalFetched += $fetchedCount;
                usleep(300000); // 0.3s delay
            }

            $msg = "Successfully synced {$totalFetched} recent credit memos from PPTC_V5_PROD.";
            $this->info($msg);
            
            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
        } catch (\Exception $e) {
            $msg = "Error syncing credit memos: " . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        }
    }
}
