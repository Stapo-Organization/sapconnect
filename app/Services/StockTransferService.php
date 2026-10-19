<?php

namespace App\Services;

use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use App\Models\StockTransferLog;
use App\Services\SAP\SapClient;
use App\Services\NotificationService;
use App\Services\NotificationRouter;
use App\Services\EmailNotificationService;
use App\Support\NotificationAudience;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;

class StockTransferService
{
    protected $sap;
    protected $notificationService;
    protected $notificationRouter;

    public function __construct(SapClient $sap)
    {
        $this->sap = $sap;
        $this->notificationService = new NotificationService();
        $this->notificationRouter = new NotificationRouter($this->notificationService);
    }

    public function setDatabase($db)
    {
        $this->sap->setCompanyDb($db);
    }

    public function importFromSap($fullSync = false)
    {
        Log::info("StockTransferService: Starting Import. Full Sync: " . ($fullSync ? 'Yes' : 'No'));

        $activeDb = $this->sap->getCompanyDb();

        // Determine Last Sync Date from the unified table
        $lastUpdate = StockTransfer::where('sap_database', $activeDb)->where('doc_type', StockTransfer::TYPE_REQUEST)->max('update_date');

        // Build filter
        if ($lastUpdate && !$fullSync) {
            $minDate = Carbon::parse($lastUpdate)->format('Y-m-d');
            $filter = "CreationDate ge '$minDate' or UpdateDate ge '$minDate'";
        } else {
            $filter = "CreationDate ge '2015-01-01'";
        }

        $newCount = 0;
        $updatedCount = 0;
        $skippedCount = 0;
        $totalFetched = 0;
        $newTransferIds = [];

        try {
            $skip = 0;
            $top = 100;

            do {
                $params = [
                    '$filter' => $filter,
                    '$skip' => $skip,
                    '$top' => $top,
                ];

                $response = $this->sap->get('InventoryTransferRequests', $params);
                $data = $response['value'] ?? [];

                if (!is_array($data) || empty($data))
                    break;

                $pageCount = count($data);
                $totalFetched += $pageCount;

                foreach ($data as $row) {
                    $result = $this->syncStockTransfer($row, $activeDb);

                    if ($result['status'] === 'new') {
                        $newCount++;
                        
                        // Only add to notification array if the request was created today or later
                        $creationDate = \Carbon\Carbon::parse($result['transfer']->creation_date);
                        if ($creationDate->startOfDay()->gte(\Carbon\Carbon::today())) {
                            $newTransferIds[] = $result['transfer']->id;
                        }
                    } elseif ($result['status'] === 'updated') {
                        $updatedCount++;
                    } else {
                        $skippedCount++;
                    }
                }

                $skip += $pageCount;
            } while ($pageCount > 0);

            // Deliveries and closings SAP made without touching UpdateDate (transfers copied from requests).
            $closedCount = 0;
            if (\Illuminate\Support\Facades\Cache::add("stock-transfers:reconcile:$activeDb", 1, now()->addHour())) {
                try {
                    $closedCount = $this->reconcileClosed($activeDb);
                } catch (\Exception $e) {
                    Log::warning("StockTransferService: reconcile failed: " . $e->getMessage());
                }
            }

            // Stock transfers SAP posted without a request.
            $directCount = 0;
            try {
                $directCount = $this->importDirectTransfers($activeDb);
            } catch (\Exception $e) {
                Log::warning("StockTransferService: direct transfers failed: " . $e->getMessage());
            }

            Log::info("StockTransferService: Complete. New: $newCount, Updated: $updatedCount, Skipped: $skippedCount, Closed: $closedCount, Direct: $directCount.");

            // Notify sender warehouse users for new transfers
            if (!empty($newTransferIds)) {
                $this->notifyNewTransfers($newTransferIds);
            }

            return [
                'active_db' => $activeDb,
                'total' => $totalFetched,
                'new' => $newCount,
                'updated' => $updatedCount,
                'skipped' => $skippedCount,
                'closed' => $closedCount,
                'direct' => $directCount,
                'sample_date' => $lastUpdate,
            ];

        } catch (\Exception $e) {
            Log::error("StockTransferService: Failed: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * SAP leaves a request's UpdateDate alone when a stock transfer delivers part
     * of it or closes it, so the incremental pull never sees either: the app showed
     * nothing received and old requests stayed «New» for good. Re-read every
     * request we hold open and store SAP's delivered quantities and status.
     * Reads SAP only; returns how many SAP had closed.
     */
    protected function reconcileClosed(string $activeDb): int
    {
        $openHere = StockTransfer::where('sap_database', $activeDb)
            ->where('doc_type', StockTransfer::TYPE_REQUEST)
            ->where('document_status', 'bost_Open')
            ->pluck('doc_entry');

        $closed = 0;
        foreach ($openHere->chunk(20) as $chunk) {
            $rows = $this->sap->get('InventoryTransferRequests', [
                '$filter' => $chunk->map(fn ($de) => 'DocEntry eq ' . (int) $de)->join(' or '),
                '$top' => 20,
            ])['value'] ?? [];
            foreach ($rows as $row) {
                $existing = StockTransfer::where('sap_database', $activeDb)->where('doc_type', StockTransfer::TYPE_REQUEST)->where('doc_entry', $row['DocEntry'])->first();
                if (! $existing) {
                    continue;
                }
                DB::transaction(fn () => $this->upsertTransfer($row, $activeDb, $existing));
                if (($row['DocumentStatus'] ?? null) === 'bost_Close') {
                    $closed++;
                }
            }
        }
        if ($closed) {
            Log::info("StockTransferService: closed $closed requests SAP had closed.");
        }
        return $closed;
    }


    /**
     * Stock transfers SAP posts with no request behind them never reached the
     * app, so the receiving branch had nothing to confirm. Mirror each one into
     * a branch that has app users as already shipped: the branch scans what
     * arrived and confirms. Reads SAP only; returns how many were added.
     */
    protected function importDirectTransfers(string $activeDb): int
    {
        $floor = (string) config('sap.direct_transfers_since', '2026-10-18');
        $last = StockTransfer::where('sap_database', $activeDb)->where('doc_type', StockTransfer::TYPE_TRANSFER)->max('doc_date');
        $from = $last ? max(Carbon::parse($last)->subDays(2)->format('Y-m-d'), $floor) : $floor;

        $receivers = $this->appWarehouses();
        if (empty($receivers)) {
            return 0;
        }
        $known = StockTransfer::where('sap_database', $activeDb)->where('doc_type', StockTransfer::TYPE_TRANSFER)
            ->where('doc_date', '>=', $from)->pluck('doc_entry')->flip();

        $added = 0;
        $skip = 0;
        do {
            $page = $this->sap->get('StockTransfers', [
                '$filter' => "DocDate ge '$from'",
                '$select' => 'DocEntry,ToWarehouse',
                '$orderby' => 'DocEntry',
                '$skip' => $skip,
                '$top' => 100,
            ])['value'] ?? [];
            $skip += count($page);

            foreach ($page as $head) {
                $de = (int) $head['DocEntry'];
                $seenKey = "stock-transfers:direct-skip:$activeDb:$de";
                if (isset($known[$de]) || ! in_array($head['ToWarehouse'] ?? null, $receivers, true) || \Illuminate\Support\Facades\Cache::has($seenKey)) {
                    continue;
                }
                $doc = $this->sap->get("StockTransfers($de)", []);
                $lines = $doc['StockTransferLines'] ?? [];
                $fromRequest = collect($lines)->contains(fn ($l) => in_array((string) ($l['BaseType'] ?? ''), ['InventoryTransferRequest', '1250000001'], true));
                if ($fromRequest || empty($lines)) {
                    // Already followed through its request; remember so we stop re-reading it.
                    \Illuminate\Support\Facades\Cache::put($seenKey, 1, now()->addDays(5));
                    continue;
                }
                DB::transaction(fn () => $this->createDirectTransfer($doc, $lines, $activeDb));
                $added++;
            }
        } while (! empty($page));

        if ($added) {
            Log::info("StockTransferService: added $added direct stock transfers.");
        }
        return $added;
    }

    protected function createDirectTransfer(array $doc, array $lines, string $activeDb): StockTransfer
    {
        $memo = trim(implode(' — ', array_filter([$doc['JournalMemo'] ?? null, $doc['Comments'] ?? null])));
        $transfer = StockTransfer::create([
            'sap_database' => $activeDb,
            'doc_entry' => $doc['DocEntry'],
            'doc_type' => StockTransfer::TYPE_TRANSFER,
            'doc_num' => $doc['DocNum'],
            'from_warehouse' => $doc['FromWarehouse'] ?? null,
            'to_warehouse' => $doc['ToWarehouse'] ?? null,
            'doc_date' => isset($doc['DocDate']) ? Carbon::parse($doc['DocDate'])->format('Y-m-d') : null,
            'document_status' => $doc['DocumentStatus'] ?? null,
            // SAP already moved the stock: nothing for the sender to do, the branch confirms receipt.
            'internal_status' => StockTransfer::STATUS_SHIPPED,
            'creation_date' => isset($doc['CreationDate']) ? Carbon::parse($doc['CreationDate']) : null,
            'update_date' => isset($doc['UpdateDate']) ? Carbon::parse($doc['UpdateDate']) : null,
            'sender_notes' => $memo !== '' ? $memo : null,
        ]);

        // One line per item, in pieces (SAP lines may be cartons and may repeat an item).
        $byItem = [];
        foreach ($lines as $l) {
            $code = $l['ItemCode'];
            $pcs = (float) ($l['InventoryQuantity'] ?? $l['Quantity'] ?? 0);
            if (! isset($byItem[$code])) {
                $byItem[$code] = [
                    'item_code' => $code,
                    'item_description' => $l['ItemDescription'] ?? null,
                    'from_warehouse_code' => $l['FromWarehouseCode'] ?? null,
                    'warehouse_code' => $l['WarehouseCode'] ?? null,
                    'line_status' => $l['LineStatus'] ?? null,
                    'quantity' => 0,
                ];
            }
            $byItem[$code]['quantity'] += $pcs;
        }
        foreach ($byItem as $line) {
            $transfer->lines()->create($line + [
                'sent_quantity' => $line['quantity'],
                'received_quantity' => $line['quantity'],
                'actual_received_quantity' => 0,
            ]);
        }

        return $transfer;
    }

    /** Warehouses that have someone on the app to receive. */
    protected function appWarehouses(): array
    {
        $codes = [];
        foreach (\App\Models\User::whereNotNull('warehouse_code')->pluck('warehouse_code') as $wc) {
            $decoded = is_string($wc) ? json_decode($wc, true) : $wc;
            foreach ((array) (is_array($decoded) ? $decoded : $wc) as $c) {
                if (is_string($c) && $c !== '') {
                    $codes[$c] = true;
                }
            }
        }
        return array_keys($codes);
    }

    protected function syncStockTransfer($row, $activeDb)
    {
        return DB::transaction(function () use ($row, $activeDb) {
            $docEntry = $row['DocEntry'];
            $sapUpdateDate = isset($row['UpdateDate']) ? Carbon::parse($row['UpdateDate']) : null;
            $sapDocStatus = $row['DocumentStatus'] ?? null;

            $existing = StockTransfer::where('sap_database', $activeDb)
                ->where('doc_type', StockTransfer::TYPE_REQUEST)
                ->where('doc_entry', $docEntry)
                ->first();

            if (!$existing) {
                $transfer = $this->upsertTransfer($row, $activeDb);
                return ['status' => 'new', 'transfer' => $transfer];
            } else {
                $localUpdateDate = $existing->update_date;
                $statusChanged = $sapDocStatus && $sapDocStatus !== $existing->document_status;

                // Update if: no local date, SAP date is newer or same day, OR document status changed in SAP
                if (!$localUpdateDate || $statusChanged || ($sapUpdateDate && $sapUpdateDate->gte($localUpdateDate))) {
                    $transfer = $this->upsertTransfer($row, $activeDb, $existing);
                    return ['status' => 'updated', 'transfer' => $transfer];
                }

                return ['status' => 'skipped', 'transfer' => $existing];
            }
        });
    }

    protected function upsertTransfer($row, $database, $existingModel = null)
    {
        $attributes = [
            'sap_database' => $database,
            'doc_num' => $row['DocNum'],
            'from_warehouse' => $row['FromWarehouse'] ?? null,
            'to_warehouse' => $row['ToWarehouse'] ?? null,
            'doc_date' => isset($row['DocDate']) ? Carbon::parse($row['DocDate'])->format('Y-m-d') : null,
            'document_status' => $row['DocumentStatus'] ?? null,
            'creation_date' => isset($row['CreationDate']) ? Carbon::parse($row['CreationDate']) : null,
            'update_date' => isset($row['UpdateDate']) ? Carbon::parse($row['UpdateDate']) : null,
        ];

        // Calculate internal status from SAP data
        $linesData = $row['InventoryTransferRequestLines'] ?? $row['StockTransferLines'] ?? [];
        $totalReceived = 0;
        foreach ($linesData as $line) {
            $baseQty = $line['InventoryQuantity'] ?? $line['Quantity'] ?? 0;
            $docQty = $line['Quantity'] ?? 0;
            $ratio = $docQty > 0 ? ($baseQty / $docQty) : 1;

            $q = $baseQty;
            $r = ($line['RemainingOpenQuantity'] ?? 0) * $ratio;
            $totalReceived += max(0, $q - $r);
        }

        // Only set internal_status for new records or if SAP closes it
        if (!$existingModel) {
            if (isset($row['DocumentStatus']) && $row['DocumentStatus'] === 'bost_Close') {
                $attributes['internal_status'] = StockTransfer::STATUS_COMPLETED;
            } else {
                $attributes['internal_status'] = StockTransfer::STATUS_NEW;
            }
        } elseif (isset($row['DocumentStatus']) && $row['DocumentStatus'] === 'bost_Close') {
            // If SAP closes it, mark as Completed regardless of internal status
            $attributes['internal_status'] = StockTransfer::STATUS_COMPLETED;
        }
        // Don't overwrite internal_status for existing records that are Shipped or Received

        if ($existingModel) {
            $existingModel->update($attributes);
            $transfer = $existingModel;
        } else {
            $attributes['doc_entry'] = $row['DocEntry'];
            $transfer = StockTransfer::create($attributes);
        }

        // Sync Lines
        $lines = $row['InventoryTransferRequestLines'] ?? $row['StockTransferLines'] ?? [];
        $this->syncLines($transfer, $lines);

        return $transfer;
    }

    protected function syncLines($transfer, $lines)
    {
        $currentLines = $transfer->lines()->get();
        $matchedIds = [];

        foreach ($lines as $lineData) {
            $itemCode = $lineData['ItemCode'];
            
            $baseQty = $lineData['InventoryQuantity'] ?? $lineData['Quantity'] ?? 0;
            $docQty = $lineData['Quantity'] ?? 0;
            $ratio = $docQty > 0 ? ($baseQty / $docQty) : 1;

            $sapQty = $baseQty;
            $remainingQty = ($lineData['RemainingOpenQuantity'] ?? 0) * $ratio;
            $calculatedReceived = max(0, $sapQty - $remainingQty);

            $match = $currentLines->first(function ($l) use ($itemCode, $matchedIds) {
                return $l->item_code === $itemCode && !in_array($l->id, $matchedIds);
            });

            if ($match) {
                $match->update([
                    'item_description' => $lineData['ItemDescription'] ?? $match->item_description,
                    'quantity' => $sapQty,
                    'received_quantity' => $calculatedReceived,
                    'from_warehouse_code' => $lineData['FromWarehouseCode'] ?? $match->from_warehouse_code,
                    'warehouse_code' => $lineData['WarehouseCode'] ?? $match->warehouse_code,
                    'line_status' => $lineData['LineStatus'] ?? $match->line_status,
                ]);
                $matchedIds[] = $match->id;
            } else {
                $newLine = $transfer->lines()->create([
                    'item_code' => $itemCode,
                    'item_description' => $lineData['ItemDescription'] ?? null,
                    'quantity' => $sapQty,
                    'received_quantity' => $calculatedReceived,
                    'sent_quantity' => 0,
                    'actual_received_quantity' => 0,
                    'from_warehouse_code' => $lineData['FromWarehouseCode'] ?? null,
                    'warehouse_code' => $lineData['WarehouseCode'] ?? null,
                    'line_status' => $lineData['LineStatus'] ?? null,
                ]);
                $matchedIds[] = $newLine->id;
            }
        }

        $transfer->lines()->whereNotIn('id', $matchedIds)->delete();
    }

    /**
     * Notify sender warehouse users about new transfers.
     */
    protected function notifyNewTransfers(array $transferIds): void
    {
        $transfers = StockTransfer::with('lines')->whereIn('id', $transferIds)->get();

        // 1. In-App Notification (Database)
        // We can still group these or send individually. Let's send individually to match emails if preferred, 
        // but the current implementation groups them. Grouping for in-app is fine, but let's notify warehouse 
        // users per transfer to be consistent with emails.
        
        foreach ($transfers as $transfer) {
            $fromWarehouseCode = $transfer->from_warehouse;
            $toWarehouseCode = $transfer->to_warehouse ?? 'Unknown';
            $docNum = $transfer->doc_num;

            // الإشعار (بريد + Push) يُوجَّه أدناه عبر NotificationRouter حسب تفضيل كل مستخدم.

            // Generate HTML table for items
            // Arabic Table
            $itemsHtmlAr = '<table style="width:100%; border-collapse: collapse; margin-top: 15px; font-size: 14px;" border="1" bordercolor="#e1e5eb" cellpadding="10">';
            $itemsHtmlAr .= '<tr style="background:#f9fafc; color:#2B3A42; text-align:right;">
                                <th>صورة المنتج</th>
                                <th>كود المنتج</th>
                                <th>وصف المنتج</th>
                                <th>الكمية المُرسلة</th>
                             </tr>';

            // English Table
            $itemsHtmlEn = '<table style="width:100%; border-collapse: collapse; margin-top: 15px; font-size: 14px;" border="1" bordercolor="#e1e5eb" cellpadding="10">';
            $itemsHtmlEn .= '<tr style="background:#f9fafc; color:#2B3A42; text-align:left;">
                                <th>Product Image</th>
                                <th>Item Code</th>
                                <th>Description</th>
                                <th>Quantity Sent</th>
                             </tr>';

            foreach ($transfer->lines as $line) {
                $code = $line->item_code;
                $imgFolder = substr($code, 0, 4);
                $imgUrl = "https://ppte.sa/img/{$imgFolder}/{$code}.png";
                $imgHtml = "<img src=\"{$imgUrl}\" alt=\"{$code}\" style=\"width: 60px; height: 60px; object-fit: contain; border-radius: 4px; border: 1px solid #eee;\" onerror=\"this.style.display='none'\">";
                
                $qty = (float) $line->quantity;
                $desc = htmlspecialchars($line->item_description ?? '');

                $itemsHtmlAr .= "<tr>
                                    <td style=\"text-align:center;\">{$imgHtml}</td>
                                    <td>{$code}</td>
                                    <td>{$desc}</td>
                                    <td><strong>{$qty}</strong></td>
                                 </tr>";

                $itemsHtmlEn .= "<tr>
                                    <td style=\"text-align:center;\">{$imgHtml}</td>
                                    <td>{$code}</td>
                                    <td>{$desc}</td>
                                    <td><strong>{$qty}</strong></td>
                                 </tr>";
            }
            $itemsHtmlAr .= '</table>';
            $itemsHtmlEn .= '</table>';

            // 2. توجيه موحّد: بريد (قالب قابل للتحرير) + Push، لكل مستخدمي المستودع
            //    المُرسِل، محترماً تفضيل القناة لكل واحد (إيميل/تطبيق/الاثنين).
            try {
                $variables = [
                    'doc_num' => $docNum,
                    'from_warehouse' => $fromWarehouseCode,
                    'to_warehouse' => $toWarehouseCode,
                    'link' => url('/admin/stock-transfers/' . $transfer->id),
                    'items_table_ar' => $itemsHtmlAr,
                    'items_table_en' => $itemsHtmlEn,
                ];

                $this->notificationRouter->route(
                    'stock_transfer_created',
                    NotificationAudience::warehouseUsers($fromWarehouseCode),
                    [
                        'title' => "طلب تحويل جديد #{$docNum}",
                        'body'  => "يوجد طلب تحويل جديد من {$fromWarehouseCode} إلى {$toWarehouseCode}. يرجى مراجعة وتأكيد الكميات.",
                        'data'  => ['type' => 'stock_transfer', 'transfer_id' => (string) $transfer->id],
                        'email_variables' => $variables,
                    ]
                );

            } catch (\Exception $e) {
                Log::error("StockTransferService: notification routing failed for transfer {$docNum}: " . $e->getMessage());
            }
        }
    }
}
