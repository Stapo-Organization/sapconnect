<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\WarehouseItemStock;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;

class SyncRecentStock extends Command
{
    protected $signature = 'sap:sync-recent-stock';
    protected $description = 'Smart sync of SAP Product Stock updates';

    public function handle()
    {
        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }
        
        $this->info("Starting Smart Stock Sync...");
        $syncStartTime = now();

        try {
            $sapClient = app(\App\Services\SAP\SapClient::class);
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            $skip = 0;
            $pageSize = 50;
            $totalSynced = 0;

            // Notice we wrap the OData array keys with single quotes so PHP doesn't resolve $ variables here.
            while (true) {
                $response = $sapClient->get('Items', [
                    '$select' => 'ItemCode,ItemWarehouseInfoCollection',
                    '$filter' => "startswith(ItemCode, 'P')",
                    '$top' => $pageSize,
                    '$skip' => $skip,
                    '$orderby' => 'ItemCode'
                ]);

                $items = $response['value'] ?? [];
                if (empty($items)) {
                    break;
                }

                $fetchedCount = count($items);
                DB::beginTransaction();
                foreach ($items as $item) {
                    $itemCode = $item['ItemCode'];
                    $warehousesInfo = $item['ItemWarehouseInfoCollection'] ?? [];
                    
                    foreach ($warehousesInfo as $whs) {
                        $warehouseCode = $whs['WarehouseCode'] ?? null;
                        $inStock = $whs['InStock'] ?? 0;

                        if ($warehouseCode && $inStock != 0) {
                            WarehouseItemStock::updateOrCreate(
                                [
                                    'item_code' => $itemCode,
                                    'warehouse_code' => $warehouseCode,
                                ],
                                [
                                    'in_stock' => $inStock,
                                    'updated_at' => now(), // Explicitly touch updated_at to track freshness
                                ]
                            );
                        }
                    }
                }
                DB::commit();

                $skip += $fetchedCount;
                $totalSynced += $fetchedCount;
                usleep(200000); // 0.2s explicit throttling limit bypass
            }

            // Cleanup: Any stock record that wasn't updated in this run means it was either 0 or completely deleted/withdrawn in SAP.
            // So we safely drop them locally to keep our stock exact and blazingly fast.
            $deletedRecords = WarehouseItemStock::where('updated_at', '<', $syncStartTime)->delete();

            $msg = "Smart Stock Sync completed. Processed {$totalSynced} items. Cleaned up {$deletedRecords} stale zero-stock records.";
            $this->info($msg);
            
            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
        } catch (\Exception $e) {
            $msg = "Error syncing recent stock: " . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        }
    }
}
