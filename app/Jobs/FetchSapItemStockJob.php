<?php

namespace App\Jobs;

use App\Models\Product;
use App\Models\WarehouseItemStock;
use App\Services\SAP\SapClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;

class FetchSapItemStockJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 3600; // 1 hour

    public function handle(SapClient $sapClient): void
    {
        ini_set('memory_limit', '2048M');
        DB::disableQueryLog();

        try {
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            // 1. Truncate current stock
            DB::statement('SET FOREIGN_KEY_CHECKS=0;');
            WarehouseItemStock::truncate();
            DB::statement('SET FOREIGN_KEY_CHECKS=1;');
            
            Log::info("FetchSapItemStockJob: Truncated WarehouseItemStock successfully.");

            // 2. Fetch stock (Items with ItemWarehouseInfoCollection)
            $totalFetched = 0;
            $retryCount = 0;
            $pageSize = 50;
            $skip = 0;

            while (true) {
                try {
                    $response = $sapClient->get('Items', [
                        '$select' => 'ItemCode,ItemWarehouseInfoCollection',
                        '$filter' => "startswith(ItemCode, 'P')",
                        '$top' => $pageSize,
                        '$skip' => $skip,
                        '$orderby' => 'ItemCode'
                    ]);
                    
                    $retryCount = 0; // Reset on success

                    $items = $response['value'] ?? [];
                    if (empty($items)) {
                        Log::info("FetchSapItemStockJob: Finished fetching all items.");
                        break;
                    }

                    $fetchedCount = count($items);
                    Log::info("FetchSapItemStockJob: Fetched {\$fetchedCount} items from SAP. (Skip: {\$skip})");

                    DB::beginTransaction();
                    foreach ($items as $item) {
                        $itemCode = $item['ItemCode'];
                        $warehousesInfo = $item['ItemWarehouseInfoCollection'] ?? [];
                        
                        foreach ($warehousesInfo as $whs) {
                            $warehouseCode = $whs['WarehouseCode'] ?? null;
                            $inStock = $whs['InStock'] ?? 0;
                            $ordered = $whs['Ordered'] ?? 0;

                            // We only store the record if the stock or ordered is not zero. This drastically reduces database size.
                            // Since we truncated the table beforehand, missing records implicitly mean 0 stock and 0 ordered.
                            if ($warehouseCode && ($inStock != 0 || $ordered != 0)) {
                                WarehouseItemStock::create([
                                    'item_code' => $itemCode,
                                    'warehouse_code' => $warehouseCode,
                                    'in_stock' => $inStock,
                                    'ordered' => $ordered
                                ]);
                            }
                        }
                    }
                    DB::commit();

                    $skip += $fetchedCount;
                    $totalFetched += $fetchedCount;
                    unset($items, $response);
                    gc_collect_cycles();
                    
                    usleep(100000); // 0.1s delay to prevent SAP throttling
                } catch (\Exception $e) {
                    $retryCount++;
                    Log::error("FetchSapItemStockJob: Error at skip {\$skip}. Retrying ({\$retryCount}/5)...", ['msg' => $e->getMessage()]);
                    if ($retryCount >= 5) {
                        Log::error("FetchSapItemStockJob: Max retries reached. Aborting.");
                        throw $e;
                    }
                    sleep(3);
                }
            }

            Log::info("FetchSapItemStockJob: Successfully completed syncing stock for {\$totalFetched} items.");
        } catch (\Exception $e) {
            Log::error("FetchSapItemStockJob Failed: " . $e->getMessage());
        }
    }
}
