<?php

namespace App\Services\Counting;

use App\Models\Product;
use App\Models\ProductAbcClassification;
use App\Models\SapInvoiceLine;
use App\Models\WarehouseItemStock;
use Illuminate\Support\Facades\DB;

class AbcClassificationService
{
    /**
     * Classify all products in a warehouse into ABC categories based on sales value.
     *
     * Logic:
     * 1. Pull sales data from SapInvoiceLine for the last N months
     * 2. Calculate total sales value per item (quantity × unit_price from Product)
     * 3. Rank by cumulative sales value (Pareto principle)
     * 4. A = top items covering 80% of sales value (~10-20% of SKUs)
     * 5. B = next items covering 80-95% (~15-30% of SKUs)
     * 6. C = remaining items covering 95-100% (~50-75% of SKUs)
     * 7. Items in stock with zero sales are also classified as C
     */
    public function classifyWarehouse(string $warehouseCode, int $monthsBack = 12): array
    {
        $since = now()->subMonths($monthsBack);

        // 1. Get sales data grouped by item_code
        $salesData = SapInvoiceLine::where('warehouse_code', $warehouseCode)
            ->whereHas('invoice', function ($q) use ($since) {
                $q->where('doc_date', '>=', $since);
            })
            ->selectRaw('item_code, SUM(quantity) as total_qty')
            ->groupBy('item_code')
            ->orderByDesc('total_qty')
            ->get();

        // 2. Fetch product prices for value calculation
        $prices = Product::whereIn('item_code', $salesData->pluck('item_code'))
            ->pluck('prices', 'item_code')
            ->toArray();

        // Calculate sales value for each item
        $itemValues = $salesData->map(function ($item) use ($prices) {
            $priceData = $prices[$item->item_code] ?? null;
            $unitPrice = 0;

            if ($priceData) {
                $decoded = is_string($priceData) ? json_decode($priceData, true) : $priceData;
                if (is_array($decoded)) {
                    // Use the first available price
                    $unitPrice = (float) ($decoded[0]['Price'] ?? $decoded[0]['price'] ?? 0);
                }
            }

            // Fallback: if no price data, use quantity as value proxy
            $salesValue = $unitPrice > 0 ? $item->total_qty * $unitPrice : (float) $item->total_qty;

            return [
                'item_code' => $item->item_code,
                'total_qty' => (float) $item->total_qty,
                'sales_value' => $salesValue,
            ];
        })->sortByDesc('sales_value')->values();

        // 3. Calculate cumulative percentage and assign ABC class
        $totalValue = $itemValues->sum('sales_value');

        if ($totalValue == 0) {
            // No sales data — classify everything as C
            $this->classifyAllAsC($warehouseCode);
            return ['A' => 0, 'B' => 0, 'C' => 0, 'total' => 0];
        }

        $cumulative = 0;
        $classifications = [];

        foreach ($itemValues as $item) {
            $cumulative += $item['sales_value'];
            $cumulativePct = ($cumulative / $totalValue) * 100;

            if ($cumulativePct <= 80) {
                $abcClass = 'A';
            } elseif ($cumulativePct <= 95) {
                $abcClass = 'B';
            } else {
                $abcClass = 'C';
            }

            $classifications[] = [
                'item_code' => $item['item_code'],
                'abc_class' => $abcClass,
                'annual_sales_value' => round($item['sales_value'], 2),
                'annual_sales_qty' => $item['total_qty'],
            ];
        }

        // 4. Get current stock data
        $stockMap = WarehouseItemStock::where('warehouse_code', $warehouseCode)
            ->where('in_stock', '>', 0)
            ->pluck('in_stock', 'item_code')
            ->toArray();

        // 5. Add items with stock but no sales as class C
        $classifiedItemCodes = collect($classifications)->pluck('item_code')->toArray();
        foreach ($stockMap as $itemCode => $stock) {
            if (!in_array($itemCode, $classifiedItemCodes)) {
                $classifications[] = [
                    'item_code' => $itemCode,
                    'abc_class' => 'C',
                    'annual_sales_value' => 0,
                    'annual_sales_qty' => 0,
                ];
            }
        }

        // 6. Upsert into database
        $now = now();
        foreach ($classifications as $item) {
            ProductAbcClassification::updateOrCreate(
                [
                    'item_code' => $item['item_code'],
                    'warehouse_code' => $warehouseCode,
                ],
                [
                    'abc_class' => $item['abc_class'],
                    'annual_sales_value' => $item['annual_sales_value'],
                    'annual_sales_qty' => $item['annual_sales_qty'],
                    'current_stock' => $stockMap[$item['item_code']] ?? 0,
                    'last_calculated_at' => $now,
                ]
            );
        }

        // Remove classifications for items no longer in stock or having sales
        ProductAbcClassification::where('warehouse_code', $warehouseCode)
            ->whereNotIn('item_code', collect($classifications)->pluck('item_code'))
            ->delete();

        $counts = collect($classifications)->groupBy('abc_class')->map->count();

        return [
            'A' => $counts->get('A', 0),
            'B' => $counts->get('B', 0),
            'C' => $counts->get('C', 0),
            'total' => count($classifications),
        ];
    }

    /**
     * Get ABC summary for a warehouse.
     */
    public function getWarehouseSummary(string $warehouseCode): array
    {
        $data = ProductAbcClassification::where('warehouse_code', $warehouseCode)
            ->selectRaw("abc_class, COUNT(*) as count, SUM(annual_sales_value) as total_value, SUM(current_stock) as total_stock")
            ->groupBy('abc_class')
            ->get()
            ->keyBy('abc_class');

        return [
            'warehouse_code' => $warehouseCode,
            'A' => [
                'count' => $data->get('A')?->count ?? 0,
                'total_value' => round($data->get('A')?->total_value ?? 0, 2),
                'total_stock' => round($data->get('A')?->total_stock ?? 0, 0),
            ],
            'B' => [
                'count' => $data->get('B')?->count ?? 0,
                'total_value' => round($data->get('B')?->total_value ?? 0, 2),
                'total_stock' => round($data->get('B')?->total_stock ?? 0, 0),
            ],
            'C' => [
                'count' => $data->get('C')?->count ?? 0,
                'total_value' => round($data->get('C')?->total_value ?? 0, 2),
                'total_stock' => round($data->get('C')?->total_stock ?? 0, 0),
            ],
            'last_calculated_at' => ProductAbcClassification::where('warehouse_code', $warehouseCode)->max('last_calculated_at'),
        ];
    }

    private function classifyAllAsC(string $warehouseCode): void
    {
        $stockItems = WarehouseItemStock::where('warehouse_code', $warehouseCode)
            ->where('in_stock', '>', 0)
            ->get();

        $now = now();
        foreach ($stockItems as $item) {
            ProductAbcClassification::updateOrCreate(
                ['item_code' => $item->item_code, 'warehouse_code' => $warehouseCode],
                [
                    'abc_class' => 'C',
                    'annual_sales_value' => 0,
                    'annual_sales_qty' => 0,
                    'current_stock' => $item->in_stock,
                    'last_calculated_at' => $now,
                ]
            );
        }
    }
}
