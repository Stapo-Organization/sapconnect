<?php

namespace App\Console\Commands;

use App\Models\SapCreditMemo;
use App\Models\SapCreditMemoLine;
use App\Models\SapInvoice;
use App\Models\SapInvoiceLine;
use App\Services\SAP\SapClient;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * One-time / periodic backfill of SAP actual per-line economics (LineTotal,
 * GrossBuyPrice, GrossProfit) onto already-synced invoice & credit-note lines,
 * so the Retail Dashboard shows REAL gross profit for historical periods.
 *
 *   php artisan sap:backfill-line-profit --from=2026-06-01
 *   php artisan sap:backfill-line-profit --days=35
 *
 * Read-only against SAP (SapClient->get). Idempotent (delete+re-insert lines).
 */
class BackfillLineProfit extends Command
{
    protected $signature = 'sap:backfill-line-profit {--from= : Start date Y-m-d} {--days=35 : Days back if --from omitted}';

    protected $description = 'Backfill SAP actual gross profit/cost onto invoice & credit-note lines (read-only).';

    public function handle(SapClient $sapClient): int
    {
        ini_set('memory_limit', '1024M'); // long paging loop; CLI default (128M) is too low
        DB::connection()->disableQueryLog(); // don't accumulate every query in memory

        $from = $this->option('from')
            ? Carbon::parse($this->option('from'))->toDateString()
            : Carbon::today()->subDays((int) $this->option('days'))->toDateString();

        $sapClient->setCompanyDb('PPTC_V5_PROD');
        $this->info("Backfilling line profit from {$from} ...");

        $inv = $this->backfill($sapClient, 'Invoices', $from, function ($doc) {
            $header = SapInvoice::updateOrCreate(
                ['doc_num' => $doc['DocNum']],
                [
                    'card_code' => $doc['CardCode'] ?? null,
                    'doc_date' => $doc['DocDate'] ?? null,
                    'doc_time' => $doc['DocTime'] ?? null,
                    'sales_employee_code' => $doc['SalesPersonCode'] ?? null,
                    'doc_total' => $doc['DocTotal'] ?? 0,
                    'cancelled' => ($doc['Cancelled'] ?? '') === 'tYES' ? 'Y' : 'N',
                ]
            );

            // Delete old lines and re-insert to fix the key collision issue
            $header->lines()->delete();

            foreach (($doc['DocumentLines'] ?? []) as $line) {
                if (empty($line['ItemCode'])) {
                    continue;
                }
                SapInvoiceLine::create([
                    'sap_invoice_id' => $header->id,
                    'line_num' => $line['LineNum'] ?? null,
                    'item_code' => $line['ItemCode'],
                    'warehouse_code' => $line['WarehouseCode'] ?? null,
                    'ocr_code' => $line['CostingCode'] ?? null,
                    'quantity' => $line['Quantity'] ?? 0,
                    'line_revenue' => $line['LineTotal'] ?? null,
                    'unit_cost' => $line['GrossBuyPrice'] ?? null,
                    'gross_profit' => $line['GrossProfit'] ?? null,
                ]);
            }
        });

        $cn = $this->backfill($sapClient, 'CreditNotes', $from, function ($doc) {
            $header = SapCreditMemo::updateOrCreate(
                ['doc_num' => $doc['DocNum']],
                [
                    'card_code' => $doc['CardCode'] ?? null,
                    'doc_date' => $doc['DocDate'] ?? null,
                    'sales_employee_code' => $doc['SalesPersonCode'] ?? null,
                    'doc_total' => $doc['DocTotal'] ?? 0,
                    'cancelled' => ($doc['Cancelled'] ?? '') === 'tYES' ? 'Y' : 'N',
                ]
            );

            // Delete old lines and re-insert
            $header->lines()->delete();

            foreach (($doc['DocumentLines'] ?? []) as $line) {
                if (empty($line['ItemCode'])) {
                    continue;
                }
                SapCreditMemoLine::create([
                    'sap_credit_memo_id' => $header->id,
                    'line_num' => $line['LineNum'] ?? null,
                    'item_code' => $line['ItemCode'],
                    'warehouse_code' => $line['WarehouseCode'] ?? null,
                    'ocr_code' => $line['CostingCode'] ?? null,
                    'quantity' => $line['Quantity'] ?? 0,
                    'price' => $line['Price'] ?? 0,
                    'line_revenue' => $line['LineTotal'] ?? null,
                    'gross_profit' => $line['GrossProfit'] ?? null,
                ]);
            }
        });

        $this->info("Done. Invoices: {$inv} · CreditNotes: {$cn}");
        return self::SUCCESS;
    }

    private function backfill(SapClient $sapClient, string $resource, string $from, callable $persist): int
    {
        $skip = 0;
        $total = 0;
        while (true) {
            $res = $sapClient->get($resource, [
                '$filter' => "DocDate ge '{$from}'",
                '$top' => 50,
                '$skip' => $skip,
                '$orderby' => 'DocEntry desc',
            ]);
            $docs = $res['value'] ?? [];
            if (empty($docs)) {
                break;
            }
            DB::beginTransaction();
            foreach ($docs as $doc) {
                $persist($doc);
            }
            DB::commit();
            $n = count($docs);
            $skip += $n;
            $total += $n;
            $this->output->write('.');
            unset($docs, $res);
            gc_collect_cycles();
            usleep(300000);
        }
        $this->newLine();
        return $total;
    }
}
