<?php

namespace App\Jobs;

use App\Models\SapInvoice;
use App\Models\SapInvoiceLine;
use App\Services\SAP\SapClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;

class FetchSapInvoicesJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 3600; // 1 hour

    public function handle(SapClient $sapClient): void
    {
        ini_set('memory_limit', '2048M');
        DB::disableQueryLog();

        $limit = 50;
        $skip = 0;

        try {
            // Target Production DB explicitly
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            // Resume from where it stopped
            $minFetchedDate = \App\Models\SapInvoice::min('doc_date') ?? now()->toDateString();
            $retryCount = 0;

            // We loop from Jan 1st up to TODAY to ensure absolutely no gaps are left behind.
            // This prevents duplicate heavy fetching by relying on updateOrCreate, while filling the massive Feb-Mar hole.
            $startDate = \Carbon\Carbon::create(2026, 1, 1);
            $endDate = \Carbon\Carbon::today();

            // Important: We fetch day by day
            for ($currentDate = clone $startDate; $currentDate->lte($endDate); $currentDate->addDay()) {
                $dateStr = $currentDate->toDateString();
                $daySkip = 0;
                
                while (true) {
                    try {
                        $response = $sapClient->get('Invoices', [
                            '$filter' => "DocDate eq '{$dateStr}'",
                            '$top' => 50,
                            '$skip' => $daySkip,
                            '$orderby' => 'DocEntry desc',
                        ]);
                        
                        $retryCount = 0; // Reset on success

                        $invoices = $response['value'] ?? [];
                        
                        if (empty($invoices)) {
                            Log::info("FetchSapInvoicesJob: Completed fetching for date {$dateStr}. Total Day Invoices: " . $daySkip);
                            break; // Done with this day
                        }
                        
                        $fetchedCount = count($invoices);
                        Log::info("FetchSapInvoicesJob: Fetched {$fetchedCount} invoices from SAP for {$dateStr}. Day Skip: {$daySkip}");

                        if (!empty($invoices)) {
                            DB::beginTransaction();
                            foreach ($invoices as $inv) {
                                $sapInvoice = SapInvoice::updateOrCreate(
                                    ['doc_num' => $inv['DocNum']],
                                    [
                                        'card_code' => $inv['CardCode'] ?? null,
                                        'doc_date' => $inv['DocDate'] ?? null,
                                        'sales_employee_code' => $inv['SalesPersonCode'] ?? null,
                                        'doc_total' => $inv['DocTotal'] ?? 0,
                                    ]
                                );

                                if (isset($inv['DocumentLines']) && is_array($inv['DocumentLines'])) {
                                    foreach ($inv['DocumentLines'] as $line) {
                                        if (!empty($line['ItemCode'])) {
                                            SapInvoiceLine::updateOrCreate(
                                                [
                                                    'sap_invoice_id' => $sapInvoice->id,
                                                    'item_code' => $line['ItemCode'],
                                                    'warehouse_code' => $line['WarehouseCode'] ?? null,
                                                ],
                                                [
                                                    'quantity' => $line['Quantity'] ?? 0,
                                                ]
                                            );
                                        }
                                    }
                                }
                            }
                            DB::commit();
                        }
                        
                        $daySkip += $fetchedCount;
                        unset($invoices, $response);
                        gc_collect_cycles();
                        
                        usleep(300000); // 0.3s delay to ensure SAP doesn't rate limit
                    } catch (\Exception $e) {
                        $retryCount++;
                        Log::error("FetchSapInvoicesJob: SAP Transient error for date {$dateStr} at skip {$daySkip}. Retrying ({$retryCount}/5)... Error: " . $e->getMessage());
                        if ($retryCount >= 5) {
                            Log::error("FetchSapInvoicesJob: Max retries reached for {$dateStr}. Skipping this date and continuing to next...");
                            break; // Do not throw exception! Just break the while loop to continue to the next day in the for loop
                        }
                        sleep(3); // Wait 3 seconds before retrying
                    }
                } // end while (day)
            } // end for (dates)
        } catch (\Exception $e) {
            Log::error("FetchSapInvoicesJob Failed: " . $e->getMessage());
        }
    }
}
