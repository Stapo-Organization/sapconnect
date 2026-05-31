<?php

namespace App\Console\Commands;

use App\Models\Brand;
use App\Models\Product;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderLine;
use App\Models\Supplier;
use App\Services\SAP\SapClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class SyncPurchaseOrders extends Command
{
    protected $signature = 'sap:sync-purchase-orders
                            {--code= : Automation code for scheduled runs}
                            {--full : Force re-sync all POs, not just open ones}';

    protected $description = 'Sync Purchase Orders from SAP and auto-link supplier-brand relationships.';

    protected SapClient $sap;

    public function handle(SapClient $sap): int
    {
        $this->sap = $sap;

        // 1. Resolve Automation Context
        $code = $this->option('code');
        $automation = null;

        if ($code) {
            $automation = \App\Models\Automation::where('code', $code)->first();
        }

        $sapDatabase = $automation ? $automation->sap_database : 'PPTC_V5_PROD';

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running',
            ]);
            $this->sap->setCompanyDb($sapDatabase);
        } else {
            $activeDb = session('sap_company_db', 'PPTC_V5_PROD');
            $this->sap->setCompanyDb($activeDb);
            $sapDatabase = $activeDb;
        }

        $this->info("Starting Purchase Orders Sync from SAP ({$sapDatabase})...");

        try {
            $page = 1;
            $totalSynced = 0;
            $totalLines = 0;
            $brandLinks = []; // supplier_id => [brand_id, ...]
            $pageSize = 50;
            $skip = 0;

            // Filter: only open POs unless --full
            $useFilter = !$this->option('full');

            do {
                $this->info("  Fetching page {$page}... (Skip: {$skip})");

                $queryParams = [
                    '$orderby' => 'DocEntry desc',
                    '$top' => $pageSize,
                    '$skip' => $skip,
                ];

                if ($useFilter) {
                    $queryParams['$filter'] = "DocumentStatus eq 'bost_Open'";
                }

                $response = $this->sap->get('PurchaseOrders', $queryParams);

                $items = $response['value'] ?? [];
                if (empty($items)) break;

                $fetchedCount = count($items);
                $this->info("    Retrieved {$fetchedCount} POs.");

                foreach ($items as $sapPO) {
                    $result = $this->syncSinglePO($sapPO, $brandLinks);
                    if ($result) {
                        $totalSynced++;
                        $totalLines += $result['lines'];
                    }
                }

                $skip += $fetchedCount;
                $page++;

            } while ($fetchedCount > 0);

            // Auto-link supplier-brand relationships
            $this->linkBrands($brandLinks);

            $msg = "PO Sync Completed: {$totalSynced} POs, {$totalLines} lines from {$sapDatabase}.";
            $this->info($msg);

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                \App\Models\AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'success',
                    'message' => $msg,
                ]);
            }

            return Command::SUCCESS;

        } catch (\Exception $e) {
            $this->error("Failed: " . $e->getMessage());
            Log::error("PO Sync Failed [{$sapDatabase}]: " . $e->getMessage());

            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                \App\Models\AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
            }

            return Command::FAILURE;
        }
    }

    /**
     * Sync a single Purchase Order from SAP.
     */
    protected function syncSinglePO(array $sapPO, array &$brandLinks): ?array
    {
        $docEntry = $sapPO['DocEntry'] ?? null;
        if (!$docEntry) return null;

        $cardCode = $sapPO['CardCode'] ?? null;
        $supplier = Supplier::where('sap_code', $cardCode)->first();

        if (!$supplier) {
            $this->line("    ⊘ Skipped PO #{$docEntry}: Supplier {$cardCode} not found locally.");
            return null;
        }

        // Determine currency
        $currency = $sapPO['DocCurrency'] ?? $supplier->currency ?? 'SAR';
        if (empty($currency) || $currency === '##') $currency = 'SAR';

        // Calculate PO total value from lines
        $docTotal = (float) ($sapPO['DocTotal'] ?? 0);
        $docStatus = $sapPO['DocumentStatus'] ?? 'Open';

        // Map SAP status
        $statusMap = [
            'bost_Open' => 'Open',
            'bost_Close' => 'Closed',
            'bost_Paid' => 'Paid',
            'bost_Delivered' => 'Delivered',
        ];

        $po = PurchaseOrder::updateOrCreate(
            ['sap_doc_entry' => $docEntry],
            [
                'sap_doc_num' => $sapPO['DocNum'] ?? null,
                'supplier_id' => $supplier->id,
                'currency' => $currency,
                'po_number' => (string) ($sapPO['DocNum'] ?? $docEntry),
                'po_value' => $docTotal,
                'doc_date' => $this->parseDate($sapPO['DocDate'] ?? null),
                'doc_due_date' => $this->parseDate($sapPO['DocDueDate'] ?? null),
                'doc_status' => $statusMap[$docStatus] ?? $docStatus,
                'sync_status' => 'synced',
                'comments' => $sapPO['Comments'] ?? null,
            ]
        );

        // Sync lines
        $lineCount = 0;
        $brandIdsForThisPO = [];

        foreach ($sapPO['DocumentLines'] ?? [] as $sapLine) {
            $itemCode = $sapLine['ItemCode'] ?? null;
            if (!$itemCode) continue;

            // Find product in our DB
            $product = Product::where('item_code', $itemCode)->first();
            $productId = $product?->id;

            // Get brand from product
            if ($product && $product->items_group_code) {
                $brand = Brand::where('code', $product->items_group_code)->first();
                if ($brand) {
                    $brandIdsForThisPO[] = $brand->id;
                    // Collect for supplier-brand linking
                    $brandLinks[$supplier->id][$brand->id] = true;
                }
            }

            PurchaseOrderLine::updateOrCreate(
                [
                    'purchase_order_id' => $po->id,
                    'sap_line_num' => $sapLine['LineNum'] ?? $lineCount,
                ],
                [
                    'item_code' => $itemCode,
                    'product_id' => $productId,
                    'description' => $sapLine['ItemDescription'] ?? null,
                    'item_description' => $sapLine['ItemDescription'] ?? null,
                    'quantity' => (int) ($sapLine['Quantity'] ?? 1),
                    'unit_price' => (float) ($sapLine['UnitPrice'] ?? 0),
                    'total_price' => (float) ($sapLine['LineTotal'] ?? 0),
                    'warehouse_code' => $sapLine['WarehouseCode'] ?? null,
                    'uom' => $sapLine['MeasureUnit'] ?? null,
                ]
            );

            $lineCount++;
        }

        // Set brand_id on PO if all lines share the same brand
        $uniqueBrands = array_unique($brandIdsForThisPO);
        if (count($uniqueBrands) === 1) {
            $po->update(['brand_id' => $uniqueBrands[0]]);
        }

        $this->line("    ✓ PO #{$docEntry} ({$supplier->name}): {$lineCount} lines — {$currency} " . number_format($docTotal, 2));

        return ['lines' => $lineCount];
    }

    /**
     * Auto-link supplier-brand relationships from real SAP PO data.
     */
    protected function linkBrands(array $brandLinks): void
    {
        $linked = 0;

        foreach ($brandLinks as $supplierId => $brandIds) {
            $supplier = Supplier::find($supplierId);
            if (!$supplier) continue;

            $ids = array_keys($brandIds);
            $supplier->brands()->syncWithoutDetaching($ids);
            $linked += count($ids);
        }

        $this->info("  🔗 Brand-Supplier links updated: {$linked} pairs from " . count($brandLinks) . " suppliers.");
    }

    /**
     * Parse SAP date format.
     */
    protected function parseDate(?string $date): ?string
    {
        if (!$date) return null;
        try {
            return \Carbon\Carbon::parse($date)->format('Y-m-d');
        } catch (\Exception $e) {
            return null;
        }
    }
}
