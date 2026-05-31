<?php

namespace App\Services\Woo;

use App\Models\WarehouseItemStock;
use App\Models\ZooboxiWarehouse;
use Illuminate\Support\Facades\DB;

/**
 * Stock management service for Zooboxi WooCommerce orders.
 *
 * Important: ZooboxiWarehouse codes (WH-RYD-01) differ from SAP warehouse codes (01, 02, etc.).
 * The `sap_warehouse_codes` JSON field on ZooboxiWarehouse bridges this mapping.
 * If no mapping is configured, we fall back to querying all SAP warehouses.
 */
class WooStockService
{
    /**
     * Get the mapping from Zooboxi warehouse code → SAP warehouse codes.
     *
     * @return array ['WH-RYD-01' => ['01','02'], 'WH-JED-01' => ['03'], ...]
     */
    private function getSapWarehouseMapping(): array
    {
        $mapping = [];
        $warehouses = ZooboxiWarehouse::active()->get();

        foreach ($warehouses as $wh) {
            $sapCodes = $wh->sap_warehouse_codes;
            if (!empty($sapCodes)) {
                $mapping[$wh->warehouse_code] = is_array($sapCodes) ? $sapCodes : json_decode($sapCodes, true);
            }
        }

        return $mapping;
    }

    /**
     * Get all SAP warehouse codes that are mapped to any Zooboxi warehouse.
     * Falls back to ALL warehouse codes in stock table if no mapping configured.
     */
    private function getAllSapWarehouseCodes(): array
    {
        $mapping = $this->getSapWarehouseMapping();

        if (!empty($mapping)) {
            // Flatten all mapped SAP codes
            $codes = [];
            foreach ($mapping as $sapCodes) {
                $codes = array_merge($codes, $sapCodes);
            }
            return array_unique($codes);
        }

        // Fallback: use ALL warehouse codes from the stock table
        return WarehouseItemStock::distinct()->pluck('warehouse_code')->toArray();
    }

    /**
     * Get stock for a specific product across all mapped warehouses.
     *
     * @return array ['item_code' => string, 'warehouses' => [...], 'total_stock' => float]
     */
    public function getStockForProduct(string $itemCode): array
    {
        $sapCodes = $this->getAllSapWarehouseCodes();
        $mapping = $this->getSapWarehouseMapping();

        $stocks = WarehouseItemStock::where('item_code', $itemCode)
            ->whereIn('warehouse_code', $sapCodes)
            ->get();

        // Group SAP stock under Zooboxi warehouse codes
        $warehouseStocks = $this->mapStocksToZooboxi($stocks, $mapping);

        return [
            'item_code' => $itemCode,
            'warehouses' => $warehouseStocks,
            'total_stock' => $stocks->sum('in_stock'),
        ];
    }

    /**
     * Get stock for all WooCommerce-synced products.
     */
    public function getAllStock(): array
    {
        $sapCodes = $this->getAllSapWarehouseCodes();
        $mapping = $this->getSapWarehouseMapping();

        $stocks = WarehouseItemStock::whereIn('warehouse_code', $sapCodes)
            ->whereHas('product', fn($q) => $q->where('woo_sync', true))
            ->get()
            ->groupBy('item_code');

        return $stocks->map(function ($warehouseStocks, $itemCode) use ($mapping) {
            return [
                'item_code' => $itemCode,
                'warehouses' => $this->mapStocksToZooboxi($warehouseStocks, $mapping),
                'total_stock' => $warehouseStocks->sum('in_stock'),
            ];
        })->values()->toArray();
    }

    /**
     * Get stock for a specific Zooboxi warehouse (resolves to SAP codes).
     */
    public function getWarehouseStock(string $warehouseCode): array
    {
        $mapping = $this->getSapWarehouseMapping();
        $sapCodes = $mapping[$warehouseCode] ?? [$warehouseCode];

        return WarehouseItemStock::whereIn('warehouse_code', $sapCodes)
            ->whereHas('product', fn($q) => $q->where('woo_sync', true))
            ->get()
            ->map(fn($s) => [
                'item_code' => $s->item_code,
                'in_stock' => (float) $s->in_stock,
                'ordered' => (float) $s->ordered,
            ])->toArray();
    }

    /**
     * Check if a warehouse has all items in the required quantities.
     * Resolves Zooboxi warehouse code to SAP codes for availability check.
     *
     * @param string $warehouseCode Zooboxi warehouse code (e.g. WH-RYD-01)
     * @param array $items Array of ['item_code' => string, 'quantity' => float]
     * @return array ['available' => bool, 'missing' => [...]]
     */
    public function checkAvailability(string $warehouseCode, array $items): array
    {
        $mapping = $this->getSapWarehouseMapping();
        $sapCodes = $mapping[$warehouseCode] ?? [$warehouseCode];
        $missing = [];

        foreach ($items as $item) {
            // Sum stock across all SAP warehouses mapped to this Zooboxi warehouse
            $available = (float) WarehouseItemStock::where('item_code', $item['item_code'])
                ->whereIn('warehouse_code', $sapCodes)
                ->sum('in_stock');

            $required = (float) ($item['quantity'] ?? 1);

            if ($available < $required) {
                $missing[] = [
                    'item_code' => $item['item_code'],
                    'required' => $required,
                    'available' => $available,
                    'shortage' => $required - $available,
                ];
            }
        }

        return [
            'available' => empty($missing),
            'missing' => $missing,
        ];
    }

    /**
     * Deduct stock from SAP warehouses for an order.
     * Uses a database transaction to prevent race conditions.
     */
    public function deductStock(array $items): bool
    {
        $mapping = $this->getSapWarehouseMapping();

        return DB::transaction(function () use ($items, $mapping) {
            foreach ($items as $item) {
                $sapCodes = $mapping[$item['warehouse_code']] ?? [$item['warehouse_code']];
                $remaining = (float) $item['quantity'];

                // Deduct from SAP warehouses in order
                foreach ($sapCodes as $sapCode) {
                    if ($remaining <= 0) break;

                    $stock = WarehouseItemStock::where('item_code', $item['item_code'])
                        ->where('warehouse_code', $sapCode)
                        ->first();

                    if (!$stock || $stock->in_stock <= 0) continue;

                    $deduct = min($remaining, (float) $stock->in_stock);
                    $stock->decrement('in_stock', $deduct);
                    $remaining -= $deduct;
                }

                if ($remaining > 0) {
                    throw new \RuntimeException(
                        "Insufficient stock for {$item['item_code']} in warehouse {$item['warehouse_code']} (shortage: {$remaining})"
                    );
                }
            }

            return true;
        });
    }

    /**
     * Restore stock to a warehouse (e.g., on order cancellation).
     */
    public function restoreStock(array $items): void
    {
        $mapping = $this->getSapWarehouseMapping();

        DB::transaction(function () use ($items, $mapping) {
            foreach ($items as $item) {
                $sapCodes = $mapping[$item['warehouse_code']] ?? [$item['warehouse_code']];
                // Restore to the first SAP warehouse in the mapping
                $primaryCode = $sapCodes[0] ?? $item['warehouse_code'];

                WarehouseItemStock::updateOrCreate(
                    ['item_code' => $item['item_code'], 'warehouse_code' => $primaryCode],
                    []
                )->increment('in_stock', $item['quantity']);
            }
        });
    }

    /**
     * Map raw SAP stock records to Zooboxi warehouse codes.
     * Aggregates stock from multiple SAP warehouses into one Zooboxi warehouse.
     */
    private function mapStocksToZooboxi($stocks, array $mapping): array
    {
        if (empty($mapping)) {
            // No mapping — return raw SAP warehouse codes
            return $stocks->map(fn($s) => [
                'warehouse_code' => $s->warehouse_code,
                'in_stock' => (float) $s->in_stock,
                'ordered' => (float) ($s->ordered ?? 0),
            ])->values()->toArray();
        }

        // Build reverse map: SAP code → Zooboxi code
        $reverseMap = [];
        foreach ($mapping as $zbxCode => $sapCodes) {
            foreach ($sapCodes as $sapCode) {
                $reverseMap[$sapCode] = $zbxCode;
            }
        }

        // Aggregate
        $aggregated = [];
        foreach ($stocks as $s) {
            $zbxCode = $reverseMap[$s->warehouse_code] ?? $s->warehouse_code;
            if (!isset($aggregated[$zbxCode])) {
                $aggregated[$zbxCode] = ['warehouse_code' => $zbxCode, 'in_stock' => 0, 'ordered' => 0];
            }
            $aggregated[$zbxCode]['in_stock'] += (float) $s->in_stock;
            $aggregated[$zbxCode]['ordered'] += (float) ($s->ordered ?? 0);
        }

        return array_values($aggregated);
    }
}
