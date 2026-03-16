<?php

namespace App\Services;

use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use App\Models\StockTransferLog;
use App\Services\SAP\SapClient;
use App\Services\NotificationService;
use App\Services\EmailNotificationService;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;

class StockTransferService
{
    protected $sap;
    protected $notificationService;

    public function __construct(SapClient $sap)
    {
        $this->sap = $sap;
        $this->notificationService = new NotificationService();
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
        $lastUpdate = StockTransfer::where('sap_database', $activeDb)->max('update_date');

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
                        $newTransferIds[] = $result['transfer']->id;
                    } elseif ($result['status'] === 'updated') {
                        $updatedCount++;
                    } else {
                        $skippedCount++;
                    }
                }

                $skip += $pageCount;
            } while ($pageCount > 0);

            Log::info("StockTransferService: Complete. New: $newCount, Updated: $updatedCount, Skipped: $skippedCount.");

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
                'sample_date' => $lastUpdate,
            ];

        } catch (\Exception $e) {
            Log::error("StockTransferService: Failed: " . $e->getMessage());
            throw $e;
        }
    }

    protected function syncStockTransfer($row, $activeDb)
    {
        return DB::transaction(function () use ($row, $activeDb) {
            $docEntry = $row['DocEntry'];
            $sapUpdateDate = isset($row['UpdateDate']) ? Carbon::parse($row['UpdateDate']) : null;

            $existing = StockTransfer::where('sap_database', $activeDb)
                ->where('doc_entry', $docEntry)
                ->first();

            if (!$existing) {
                $transfer = $this->upsertTransfer($row, $activeDb);
                return ['status' => 'new', 'transfer' => $transfer];
            } else {
                $localUpdateDate = $existing->update_date;

                if (!$localUpdateDate || ($sapUpdateDate && $sapUpdateDate->gt($localUpdateDate))) {
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
            $q = $line['Quantity'] ?? 0;
            $r = $line['RemainingOpenQuantity'] ?? 0;
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
            $sapQty = $lineData['Quantity'] ?? 0;
            $remainingQty = $lineData['RemainingOpenQuantity'] ?? 0;
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

            // In-App Notification
            try {
                $this->notificationService->notifyWarehouseUsers(
                    $fromWarehouseCode,
                    "طلب تحويل جديد #{$docNum}",
                    "يوجد طلب تحويل جديد من {$fromWarehouseCode} إلى {$toWarehouseCode}. يرجى مراجعة وتأكيد الكميات.",
                    ['transfer_id' => $transfer->id]
                );
            } catch (\Exception $e) {
                Log::error("StockTransferService: In-App Notification failed for transfer {$docNum}: " . $e->getMessage());
            }

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

            // 2. Email Notification System (Dynamic)
            try {
                $variables = [
                    'doc_num' => $docNum,
                    'from_warehouse' => $fromWarehouseCode,
                    'to_warehouse' => $toWarehouseCode,
                    'link' => url('/admin/stock-transfers/' . $transfer->id), 
                    'items_table_ar' => $itemsHtmlAr,
                    'items_table_en' => $itemsHtmlEn,
                ];

                $context = [
                    'from_warehouse' => $fromWarehouseCode,
                    'to_warehouse' => $toWarehouseCode,
                ];

                EmailNotificationService::dispatch('stock_transfer_created', $variables, $context);

            } catch (\Exception $e) {
                Log::error("StockTransferService: Dynamic Email Notification failed for transfer {$docNum}: " . $e->getMessage());
            }
        }
    }
}
