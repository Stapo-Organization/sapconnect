<?php

namespace App\Jobs;

use App\Models\SuggestedStockTransfer;
use App\Models\Warehouse;
use App\Services\SAP\SapClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class CalculateStockOpportunitiesJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $timeout = 3600;

    /** Cache keys powering the app's "تشغيل المحرك" progress indicator. */
    public const RUNNING_KEY = 'stock_distribution:running';
    public const LAST_RUN_KEY = 'stock_distribution:last_run';

    public function handle(SapClient $sapClient): void
    {
        try {
            // Target Production DB explicitly
            $sapClient->setCompanyDb('PPTC_V5_PROD');

            // 1. Fetch local average daily sales FIRST to find active items
            // Filter strictly to last 90 days of PROD active sales AND Retail only
            $salesData = DB::table('sap_invoice_lines')
                ->join('sap_invoices', 'sap_invoice_lines.sap_invoice_id', '=', 'sap_invoices.id')
                ->leftJoin('warehouses', 'sap_invoices.sales_employee_code', '=', 'warehouses.sales_employee_code')
                ->select(
                    'sap_invoice_lines.item_code',
                    DB::raw('COALESCE(warehouses.warehouse_code, sap_invoice_lines.warehouse_code) as warehouse_code'),
                    DB::raw('SUM(sap_invoice_lines.quantity) / 90 as ads')
                )
                ->where('sap_invoices.card_code', 'C0000001') // EXACT RULE: Retail Only
                ->whereDate('sap_invoices.doc_date', '>=', now()->subDays(90)->toDateString())
                ->groupBy('sap_invoice_lines.item_code', 'warehouse_code')
                ->get()
                ->groupBy('item_code');

            $activeItemCodes = $salesData->keys()->filter()->toArray();
            
            // 2. Fetch Stock completely locally from our pre-synced table (Instantaneous!)
            $currentStock = [];
            $currentOrdered = [];
            $originalPhysicalStocks = [];
            if (!empty($activeItemCodes)) {
                $stockRecords = \App\Models\WarehouseItemStock::whereIn('item_code', $activeItemCodes)->get();
                foreach($stockRecords as $stock) {
                    $currentStock[$stock->item_code][$stock->warehouse_code] = $stock->in_stock;
                    $currentOrdered[$stock->item_code][$stock->warehouse_code] = $stock->ordered;
                    $originalPhysicalStocks[$stock->item_code][$stock->warehouse_code] = $stock->in_stock;
                }
            }

            // 3. Classify System Warehouses
            $allWarehouses = Warehouse::get();
            $stores = [];
            $centralWarehouses = ['AGL001', '3PL001', 'STL001', 'STL002'];
            $shipgoWarehouses = [];

            foreach ($allWarehouses as $whs) {
                if (stripos($whs->warehouse_name, 'ShipGo') !== false) {
                    $shipgoWarehouses[] = $whs->warehouse_code;
                } elseif (stripos($whs->warehouse_name, 'Store') !== false) {
                    $stores[] = $whs->warehouse_code;
                }
            }
            
            DB::beginTransaction();
            // Delete old pending suggestions
            SuggestedStockTransfer::where('status', 'pending')->delete();

            foreach ($currentStock as $itemCode => $whsStock) {
                $itemSales = $salesData->get($itemCode)?->keyBy('warehouse_code') ?? collect();
                
                $centralSources = [];
                $storeSources = [];
                $highDemandTargets = [];

                foreach ($whsStock as $whsCode => $stock) {
                    $orderedQty = $currentOrdered[$itemCode][$whsCode] ?? 0;
                    $ads = $itemSales->get($whsCode)->ads ?? 0;
                    $dos = $ads > 0 ? $stock / $ads : 999;
                    
                    // Categorize as CENTRAL Source (Always available to feed)
                    if (in_array($whsCode, $centralWarehouses)) {
                        if ($stock > 0) {
                            $centralSources[] = [
                                'warehouse' => $whsCode,
                                'stock' => $stock
                            ];
                        }
                    } 
                    // Categorize as STORE Source (Cross-Docking only if dead)
                    elseif (in_array($whsCode, $stores)) {
                        if ($dos > 90 && $stock > 10 && $ads < 0.1) {
                            $storeSources[] = [
                                'warehouse' => $whsCode,
                                'stock' => $stock,
                                'ads' => $ads
                            ];
                        }
                    }

                    // Categorize as TARGET (Store or ShipGo thirsty for stock)
                    if (in_array($whsCode, $stores) || in_array($whsCode, $shipgoWarehouses)) {
                        $effectiveStock = $stock + $orderedQty;
                        $effectiveDos = $ads > 0 ? $effectiveStock / $ads : 999;
                        if ($effectiveDos < 7 && $ads > 0.5) {
                            $highDemandTargets[] = [
                                'warehouse' => $whsCode,
                                'stock' => $stock,
                                'effective_stock' => $effectiveStock,
                                'ads' => $ads
                            ];
                        }
                    }
                }

                // Process Priority Engine
                foreach ($highDemandTargets as &$target) {
                    $requiredQty = ceil(($target['ads'] * 30) - $target['effective_stock']);
                    if ($requiredQty <= 0) continue;

                    // --- PASS 1: Central Warehouses Priority ---
                    foreach ($centralSources as &$source) {
                        if ($requiredQty <= 0) break;
                        if ($source['stock'] <= 0) continue;

                        $availableQty = $source['stock']; // ALL stock in central is available to replenish
                        $suggestedQty = (int) min($requiredQty, $availableQty);

                        if ($suggestedQty > 0) {
                            SuggestedStockTransfer::create([
                                'item_code' => $itemCode,
                                'source_warehouse' => $source['warehouse'],
                                'target_warehouse' => $target['warehouse'],
                                'suggested_quantity' => $suggestedQty,
                                'source_ads' => 0, // Central typically doesn't have retail ADS
                                'source_stock' => $originalPhysicalStocks[$itemCode][$source['warehouse']], 
                                'target_ads' => $target['ads'],
                                'target_stock' => $target['stock'],
                            ]);
                            
                            $source['stock'] -= $suggestedQty;
                            $target['stock'] += $suggestedQty;
                            $requiredQty -= $suggestedQty;
                        }
                    }

                    // --- PASS 2: Cross Docking Fallback ---
                    // Only try to cross-dock from another store if Central couldn't satisfy target requirement!
                    if ($requiredQty > 0) {
                        foreach ($storeSources as &$source) {
                            if ($requiredQty <= 0) break;
                            if ($source['stock'] <= 10) continue; 
                            
                            $availableQty = floor($source['stock'] - ($source['ads'] * 30));

                            if ($availableQty > 0) {
                                $suggestedQty = (int) min($requiredQty, $availableQty);
                                
                                if ($suggestedQty > 0) {
                                    SuggestedStockTransfer::create([
                                        'item_code' => $itemCode,
                                        'source_warehouse' => $source['warehouse'],
                                        'target_warehouse' => $target['warehouse'],
                                        'suggested_quantity' => $suggestedQty,
                                        'source_ads' => $source['ads'],
                                        'source_stock' => $originalPhysicalStocks[$itemCode][$source['warehouse']],
                                        'target_ads' => $target['ads'],
                                        'target_stock' => $target['stock'],
                                    ]);
                                    
                                    $source['stock'] -= $suggestedQty;
                                    $target['stock'] += $suggestedQty;
                                    $requiredQty -= $suggestedQty;
                                }
                            }
                        }
                    }
                }
            }
            DB::commit();

            // Stamp completion so the app can show "آخر تشغيل" and drop the spinner.
            Cache::forever(self::LAST_RUN_KEY, now()->toIso8601String());
            Cache::forget(self::RUNNING_KEY);

        } catch (\Exception $e) {
            DB::rollBack();
            Cache::forget(self::RUNNING_KEY);
            Log::error("CalculateStockOpportunitiesJob Failed: " . $e->getMessage());
            throw $e;
        }
    }

    /** Ensure the running flag is cleared even if the job ultimately fails. */
    public function failed(\Throwable $e): void
    {
        Cache::forget(self::RUNNING_KEY);
    }
}
