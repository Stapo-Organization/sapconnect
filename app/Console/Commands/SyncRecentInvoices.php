<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\SapInvoice;
use App\Models\SapInvoiceLine;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class SyncRecentInvoices extends Command
{
    protected $signature = 'sap:sync-recent-invoices';
    protected $description = 'Sync recent SAP Invoices (last 3 days)';

    public function handle()
    {
        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }
        
        $this->info("Starting Recent Invoices Sync...");

        try {
            $sapClient = app(\App\Services\SAP\SapClient::class);
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            // We sync the last 3 days to catch all delayed entries and runtime updates safely without triggering SAP scale issues
            $startDate = Carbon::today()->subDays(2)->toDateString();
            
            $skip = 0;
            $totalFetched = 0;
            
            while (true) {
                $response = $sapClient->get('Invoices', [
                    '$filter' => "DocDate ge '{$startDate}' and Cancelled eq 'tNO'",
                    '$top' => 50,
                    '$skip' => $skip,
                    '$orderby' => 'DocEntry desc'
                ]);

                $invoices = $response['value'] ?? [];
                if (empty($invoices)) {
                    break;
                }

                $fetchedCount = count($invoices);
                DB::beginTransaction();
                foreach ($invoices as $inv) {
                     $sapInvoice = SapInvoice::updateOrCreate(
                        ['doc_num' => $inv['DocNum']],
                        [
                            'card_code' => $inv['CardCode'] ?? null,
                            'doc_date' => $inv['DocDate'] ?? null,
                            'doc_time' => $inv['DocTime'] ?? null,
                            'sales_employee_code' => $inv['SalesPersonCode'] ?? null,
                            'doc_total' => $inv['DocTotal'] ?? 0,
                            'cancelled' => $inv['Cancelled'] === 'tYES' ? 'Y' : 'N',
                        ]
                    );

                    // Delete old lines for this invoice and re-insert to avoid
                    // the updateOrCreate key collision issue where same item+warehouse
                    // appears multiple times in one invoice.
                    $sapInvoice->lines()->delete();

                    if (isset($inv['DocumentLines']) && is_array($inv['DocumentLines'])) {
                        foreach ($inv['DocumentLines'] as $line) {
                            if (!empty($line['ItemCode'])) {
                                SapInvoiceLine::create([
                                    'sap_invoice_id' => $sapInvoice->id,
                                    'line_num' => $line['LineNum'] ?? null,
                                    'item_code' => $line['ItemCode'],
                                    'quantity' => $line['Quantity'] ?? 0,
                                    'warehouse_code' => $line['WarehouseCode'] ?? null,
                                    'ocr_code' => $line['CostingCode'] ?? null,
                                    // SAP actual economics (ex-VAT): real gross profit at posting.
                                    'line_revenue' => $line['LineTotal'] ?? null,
                                    'unit_cost' => $line['GrossBuyPrice'] ?? null,
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

            $msg = "Successfully synced {$totalFetched} recent invoices from PPTC_V5_PROD.";
            $this->info($msg);
            
            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
        } catch (\Exception $e) {
            $msg = "Error syncing recent invoices: " . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        }
    }
}
