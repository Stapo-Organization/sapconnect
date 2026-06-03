<?php

namespace App\Services\Counting;

use App\Models\InventoryCounting;
use App\Models\InventoryCountingLine;
use App\Models\InventoryCyclePlan;
use App\Models\ProductAbcClassification;
use App\Models\WarehouseItemStock;
use Illuminate\Support\Collection;

class VarianceCalculationService
{
    /**
     * Calculate variances for all lines in a completed counting session.
     *
     * For each line:
     * 1. Snapshot system_quantity from WarehouseItemStock
     * 2. Calculate variance = counted_quantity - system_quantity
     * 3. Calculate variance_percentage = |variance| / system_quantity × 100
     * 4. Determine variance_status based on tolerance
     *
     * Does NOT write to SAP. Does NOT auto-create uncounted lines.
     *
     * @return array Summary statistics
     */
    public function calculateForSession(InventoryCounting $counting): array
    {
        $warehouseCode = $counting->warehouse_code;

        // Determine tolerance from cycle plan or use defaults
        $tolerances = $this->getTolerances($counting);

        // Pre-fetch all stock for this warehouse in one query
        $stockMap = WarehouseItemStock::where('warehouse_code', $warehouseCode)
            ->pluck('in_stock', 'item_code')
            ->toArray();

        // Pre-fetch ABC classifications for tolerance lookup
        $abcMap = ProductAbcClassification::where('warehouse_code', $warehouseCode)
            ->pluck('abc_class', 'item_code')
            ->toArray();

        $summary = [
            'total_lines' => 0,
            'match' => 0,
            'within_tolerance' => 0,
            'over' => 0,
            'short' => 0,
            'not_in_system' => 0,
        ];

        $counting->lines->each(function (InventoryCountingLine $line) use ($stockMap, $abcMap, $tolerances, &$summary) {
            $itemCode = $line->item_code;
            $systemQty = $stockMap[$itemCode] ?? null;

            if ($systemQty === null) {
                // Product not found in warehouse stock
                $line->update([
                    'system_quantity' => 0,
                    'variance' => (float) $line->counted_quantity,
                    'variance_percentage' => 100,
                    'variance_status' => 'not_in_system',
                ]);
                $summary['not_in_system']++;
            } else {
                // Snapshot system quantity
                $line->system_quantity = (float) $systemQty;

                // Get tolerance for this item's ABC class
                $abcClass = $abcMap[$itemCode] ?? 'C';
                $tolerance = $tolerances[$abcClass] ?? 5.0;

                // Calculate variance
                $result = $line->calculateVariance($tolerance);

                $line->update([
                    'system_quantity' => (float) $systemQty,
                    'variance' => $result['variance'],
                    'variance_percentage' => $result['variance_percentage'],
                    'variance_status' => $result['variance_status'],
                ]);

                $summary[$result['variance_status']]++;
            }

            $summary['total_lines']++;
        });

        // Update ABC counting metrics
        $this->updateCountingMetrics($counting, $abcMap);

        return $summary;
    }

    /**
     * Get the list of uncounted items for this session.
     * Returns items in WarehouseItemStock that were NOT scanned.
     * This is informational only — the admin decides what to do with them.
     */
    public function getUncountedItems(InventoryCounting $counting): Collection
    {
        $countedItemCodes = $counting->lines->pluck('item_code')->toArray();

        return WarehouseItemStock::where('warehouse_code', $counting->warehouse_code)
            ->where('in_stock', '>', 0)
            ->whereNotIn('item_code', $countedItemCodes)
            ->with('product:item_code,item_name,foreign_name')
            ->get()
            ->map(function ($stock) {
                return [
                    'item_code' => $stock->item_code,
                    'item_name' => $stock->product?->item_name ?? $stock->item_code,
                    'item_name_ar' => $stock->product?->foreign_name ?? $stock->product?->item_name ?? $stock->item_code,
                    'system_quantity' => (float) $stock->in_stock,
                    'image_url' => $stock->product ? 'https://ppte.sa/imghd/' . substr($stock->item_code, 0, 4) . '/' . $stock->item_code . '.png' : null,
                ];
            });
    }

    /**
     * Get variance report summary for a completed session.
     */
    public function getVarianceReport(InventoryCounting $counting): array
    {
        $lines = $counting->lines;

        $statusCounts = $lines->groupBy('variance_status')->map->count();

        $totalCounted = $lines->sum('counted_quantity');
        $totalSystem = $lines->sum('system_quantity');

        // Top discrepancies (sorted by absolute variance percentage, descending)
        $discrepancies = $lines
            ->whereNotIn('variance_status', ['match', 'within_tolerance', 'uncounted'])
            ->sortByDesc(fn($l) => abs((float) $l->variance_percentage))
            ->values();

        return [
            'session_id' => $counting->id,
            'warehouse_code' => $counting->warehouse_code,
            'warehouse_name' => $counting->warehouse_name,
            'counting_type' => $counting->counting_type ?? 'full',
            'completed_at' => $counting->completed_at,
            'summary' => [
                'total_lines' => $lines->count(),
                'match' => $statusCounts->get('match', 0),
                'within_tolerance' => $statusCounts->get('within_tolerance', 0),
                'over' => $statusCounts->get('over', 0),
                'short' => $statusCounts->get('short', 0),
                'not_in_system' => $statusCounts->get('not_in_system', 0),
                'total_counted_qty' => round($totalCounted, 0),
                'total_system_qty' => round($totalSystem, 0),
                'accuracy_percentage' => $totalSystem > 0
                    ? round(100 - (abs($totalCounted - $totalSystem) / $totalSystem * 100), 2)
                    : 100,
            ],
            'discrepancies' => $discrepancies->take(50)->map(fn($l) => [
                'id' => $l->id,
                'item_code' => $l->item_code,
                'item_name' => $l->item_name,
                'item_name_ar' => $l->product?->foreign_name ?? $l->item_name,
                'piece_barcode' => $l->piece_barcode,
                'counted_quantity' => (float) $l->counted_quantity,
                'system_quantity' => (float) $l->system_quantity,
                'variance' => (float) $l->variance,
                'variance_percentage' => (float) $l->variance_percentage,
                'variance_status' => $l->variance_status,
                'investigation_note' => $l->investigation_note,
                'image_url' => $l->image_url,
            ])->values(),
        ];
    }

    // ─── Private Helpers ────────────────────────────────────────

    private function getTolerances(InventoryCounting $counting): array
    {
        if ($counting->cycle_plan_id) {
            $plan = InventoryCyclePlan::find($counting->cycle_plan_id);
            if ($plan) {
                return [
                    'A' => (float) $plan->tolerance_a,
                    'B' => (float) $plan->tolerance_b,
                    'C' => (float) $plan->tolerance_c,
                ];
            }
        }

        // Default tolerances
        return [
            'A' => 2.0,
            'B' => 5.0,
            'C' => 10.0,
        ];
    }

    /**
     * After counting is completed, update the ABC classification tracking fields.
     */
    private function updateCountingMetrics(InventoryCounting $counting, array $abcMap): void
    {
        $now = now();

        foreach ($counting->lines as $line) {
            ProductAbcClassification::where('item_code', $line->item_code)
                ->where('warehouse_code', $counting->warehouse_code)
                ->update([
                    'last_counted_at' => $now,
                    'count_in_cycle' => \DB::raw('count_in_cycle + 1'),
                    'last_variance_pct' => (float) $line->variance_percentage,
                ]);
        }
    }
}
