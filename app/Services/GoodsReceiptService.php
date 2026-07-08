<?php

namespace App\Services;

use App\Models\SapGoodsReceipt;
use App\Models\SapGoodsReceiptLine;
use App\Services\SAP\SapClient;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Imports Goods Receipt POs (GRPO) FROM SAP `PurchaseDeliveryNotes` INTO the
 * sapconnect DB (sap_goods_receipts / sap_goods_receipt_lines).
 *
 * READ-ONLY against SAP — only `SapClient->get()` is used; nothing is ever written
 * back to SAP. Mirrors the StockTransferService import pattern (setDatabase +
 * paginated, incremental-by-UpdateDate importFromSap).
 */
class GoodsReceiptService
{
    protected SapClient $sap;

    /** GRPO line fields we need (keeps the payload small). */
    private const SELECT = 'DocEntry,DocNum,DocDate,CardCode,UpdateDate,DocumentLines';

    public function __construct(SapClient $sap)
    {
        $this->sap = $sap;
    }

    public function setDatabase(string $db): void
    {
        $this->sap->setCompanyDb($db);
    }

    /**
     * @param bool        $fullSync  ignore the incremental watermark and re-pull from $since
     * @param string|null $since     backfill floor date (Y-m-d); defaults to 2024-01-01 on full sync
     */
    public function importFromSap(bool $fullSync = false, ?string $since = null): array
    {
        $activeDb = $this->sap->getCompanyDb();
        Log::info("GoodsReceiptService: import start (db={$activeDb}, full=" . ($fullSync ? 'yes' : 'no') . ")");

        // GRPO lines carry ~250 fields each; over many pages the query log + retained
        // responses balloon memory. Disable the query log and GC each page.
        DB::connection()->disableQueryLog();

        $lastUpdate = SapGoodsReceipt::where('sap_database', $activeDb)->max('update_date');

        if ($since) {
            $floor = Carbon::parse($since)->format('Y-m-d');
            $filter = "DocDate ge '{$floor}'";
        } elseif ($lastUpdate && !$fullSync) {
            $floor = Carbon::parse($lastUpdate)->format('Y-m-d');
            $filter = "UpdateDate ge '{$floor}'";
        } else {
            $filter = "DocDate ge '2024-01-01'";
        }

        $new = $updated = $skipped = $lines = 0;
        $skip = 0;
        $top = 25;

        try {
            do {
                $params = [
                    '$select'  => self::SELECT,
                    '$filter'  => $filter,
                    '$orderby' => 'UpdateDate asc',
                    '$skip'    => $skip,
                    '$top'     => $top,
                ];

                $response = $this->sap->get('PurchaseDeliveryNotes', $params);
                $data = $response['value'] ?? [];

                if (!is_array($data) || empty($data)) {
                    break;
                }

                $pageCount = count($data);

                foreach ($data as $row) {
                    $result = $this->syncOne($row, $activeDb);
                    $lines += $result['lines'];
                    match ($result['status']) {
                        'new'     => $new++,
                        'updated' => $updated++,
                        default   => $skipped++,
                    };
                }

                $skip += $pageCount;
                unset($response, $data);
                gc_collect_cycles();
            } while ($pageCount > 0);

            Log::info("GoodsReceiptService: done. new={$new} updated={$updated} skipped={$skipped} lines={$lines}");

            return [
                'active_db' => $activeDb,
                'new'       => $new,
                'updated'   => $updated,
                'skipped'   => $skipped,
                'lines'     => $lines,
            ];
        } catch (\Throwable $e) {
            Log::error('GoodsReceiptService: failed: ' . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Upsert one GRPO document + its lines inside a transaction.
     */
    protected function syncOne(array $row, string $db): array
    {
        return DB::transaction(function () use ($row, $db) {
            $docEntry = $row['DocEntry'] ?? null;
            if ($docEntry === null) {
                return ['status' => 'skipped', 'lines' => 0];
            }

            $updateDate = isset($row['UpdateDate']) ? Carbon::parse($row['UpdateDate']) : null;

            $existing = SapGoodsReceipt::where('sap_database', $db)
                ->where('doc_entry', $docEntry)
                ->first();

            // Skip if we already have this doc at the same-or-newer update timestamp.
            if ($existing && $updateDate && $existing->update_date && $existing->update_date->gte($updateDate)) {
                return ['status' => 'skipped', 'lines' => 0];
            }

            $docDate = isset($row['DocDate']) ? Carbon::parse($row['DocDate'])->toDateString() : null;

            $receipt = SapGoodsReceipt::updateOrCreate(
                ['sap_database' => $db, 'doc_entry' => $docEntry],
                [
                    'doc_num'     => $row['DocNum'] ?? null,
                    'card_code'   => $row['CardCode'] ?? null,
                    'doc_date'    => $docDate,
                    'update_date' => $updateDate,
                ]
            );

            // Replace lines wholesale (cheap; GRPO line counts are small).
            $receipt->lines()->delete();

            $lineRows = [];
            foreach (($row['DocumentLines'] ?? []) as $ln) {
                $itemCode = $ln['ItemCode'] ?? '';
                if ($itemCode === '') {
                    continue;
                }
                $lineRows[] = [
                    'sap_goods_receipt_id' => $receipt->id,
                    'line_num'             => $ln['LineNum'] ?? null,
                    // Source-doc link (BaseType 22 = Purchase Order/OPOR). Already present
                    // in DocumentLines — no $select change needed. Enables GRPO→PO joins.
                    'base_entry'           => $ln['BaseEntry'] ?? null,
                    'base_line'            => $ln['BaseLine'] ?? null,
                    'base_type'            => $ln['BaseType'] ?? null,
                    'item_code'            => $itemCode,
                    'quantity'             => (float) ($ln['Quantity'] ?? 0),
                    'inventory_quantity'   => (float) ($ln['InventoryQuantity'] ?? $ln['Quantity'] ?? 0),
                    'warehouse_code'       => $ln['WarehouseCode'] ?? null,
                    'unit_price'           => (float) ($ln['Price'] ?? 0),
                    'line_total'           => (float) ($ln['LineTotal'] ?? 0),
                    'doc_date'             => $docDate,
                    'created_at'           => now(),
                    'updated_at'           => now(),
                ];
            }

            if (!empty($lineRows)) {
                SapGoodsReceiptLine::insert($lineRows);
            }

            return ['status' => $existing ? 'updated' : 'new', 'lines' => count($lineRows)];
        });
    }
}
