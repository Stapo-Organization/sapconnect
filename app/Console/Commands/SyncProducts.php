<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog; // Corrected Import
use Illuminate\Support\Facades\Log;

class SyncProducts extends Command
{
    protected $signature = 'sap:sync-products {--code=} {--full}';
    protected $description = 'Sync Products from SAP';

    public function handle()
    {
        $code = $this->option('code');
        $automation = null;
        if ($code) {
            $automation = Automation::where('code', $code)->first();
        } else {
            // Fallback for older automations
            $automation = Automation::where('code', 'sync_products')->first();
        }

        $sapDatabase = 'PPTC_V5_PROD';

        $this->info("Starting Products Sync for $sapDatabase...");

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running'
            ]);
        }

        $this->info("Detected Environment: PRODUCTION -> Syncing source 'production'");

        try {
            $sap = app(\App\Services\SAP\SapClient::class);
            $sap->setCompanyDb($sapDatabase);

            $page = 1;
            $count = 0;
            $pageSize = 100;
            $skip = 0;
            $brandSupplierLinks = [];

            do {
                $this->info("  Fetching Products page $page... (Skip: $skip)");

                // Fetch Items with select fields, including ItemPrices
                $response = $sap->get('Items', [
                    '$select' => 'ItemCode,ItemName,ForeignName,ItemsGroupCode,InventoryUOM,BarCode,SalesItemsPerUnit,CreateDate,UpdateDate,ItemPrices,U_PortalSync,U_PROPRT1,U_PROPRT2,U_PROPRT3,U_PROPRT4,U_PROPRT5,Mainsupplier',
                    '$orderby' => 'ItemCode',
                    '$top' => $pageSize,
                    '$skip' => $skip
                ]);

                $items = $response['value'] ?? [];

                if (empty($items)) {
                    break;
                }

                $fetchedCount = count($items);
                $this->info("    - Retrieved $fetchedCount products.");

                $envSource = 'production';

                foreach ($items as $item) {
                    // Only sync products that start with "P" (e.g. P10000030)
                    if (!str_starts_with($item['ItemCode'], 'P')) {
                        continue;
                    }

                    $pricesData = $item['ItemPrices'] ?? [];

                    $data = [
                        'item_code' => $item['ItemCode'],
                        'item_name' => $item['ItemName'] ?? null,
                        'foreign_name' => $item['ForeignName'] ?? null,
                        'items_group_code' => $item['ItemsGroupCode'] ?? null,
                        'inventory_uom' => $item['InventoryUOM'] ?? null,
                        'piece_barcode' => $item['BarCode'] ?? null,
                        'sales_items_per_unit' => $item['SalesItemsPerUnit'] ?? null,
                        'create_date' => isset($item['CreateDate']) ? date('Y-m-d', strtotime($item['CreateDate'])) : null,
                        'update_date' => isset($item['UpdateDate']) ? date('Y-m-d', strtotime($item['UpdateDate'])) : null,
                        'source' => $envSource,
                        'prices' => $pricesData,
                        'u_portal_sync' => $item['U_PortalSync'] ?? null,
                        'u_proprt1' => $item['U_PROPRT1'] ?? null,
                        'u_proprt2' => $item['U_PROPRT2'] ?? null,
                        'u_proprt3' => $item['U_PROPRT3'] ?? null,
                        'u_proprt4' => $item['U_PROPRT4'] ?? null,
                        'u_proprt5' => $item['U_PROPRT5'] ?? null,
                    ];

                    \App\Models\Product::updateOrCreate(
                        [
                            'item_code' => $data['item_code'],
                            'source' => $data['source'],
                        ],
                        $data
                    );
                    
                    $mainsupplier = $item['Mainsupplier'] ?? null;
                    if ($mainsupplier && $data['items_group_code']) {
                        $brandSupplierLinks[$mainsupplier][$data['items_group_code']] = true;
                    }
                    
                    $count++;
                }

                $skip += $fetchedCount;
                $page++;

            } while (true);

            $msg = "Products Sync Completed. Processed $count records from $sapDatabase.";
            $this->info($msg);

            if (!empty($brandSupplierLinks)) {
                $this->info("Updating Brand-Supplier links based on Item's Mainsupplier...");
                $linked = 0;
                foreach ($brandSupplierLinks as $cardCode => $brandCodes) {
                    $supplier = \App\Models\Supplier::where('sap_code', $cardCode)->first();
                    if (!$supplier) continue;
                    
                    $brandIds = [];
                    foreach (array_keys($brandCodes) as $bCode) {
                        $b = \App\Models\Brand::where('code', $bCode)->first();
                        if ($b) {
                            $brandIds[] = $b->id;
                        }
                    }
                    
                    if (!empty($brandIds)) {
                        $supplier->brands()->syncWithoutDetaching($brandIds);
                        $linked += count($brandIds);
                    }
                }
                $this->info("Linked {$linked} brand-supplier pairs.");
            }

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'success',
                    'message' => $msg,
                ]);
            }
        } catch (\Exception $e) {
            $errorMsg = "Products Sync Failed: " . $e->getMessage();
            $this->error($errorMsg);
            Log::error("Products Sync Failed [$sapDatabase]: " . $e->getMessage());

            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
            }
        }
    }
}
