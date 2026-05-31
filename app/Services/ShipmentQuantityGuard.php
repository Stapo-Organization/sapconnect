<?php

namespace App\Services;

use App\Models\PurchaseOrderLine;
use App\Models\ShipmentLine;

class ShipmentQuantityGuard
{
    /**
     * Validate that the shipped quantity for a PO line does not exceed the ordered quantity.
     *
     * @param int $purchaseOrderLineId  The PO line to validate against
     * @param int $shippedQuantity      The quantity being shipped in this shipment
     * @param int|null $excludeShipmentLineId  Exclude this shipment line (for updates)
     * @return array{valid: bool, message: string, remaining: int, total_shipped: int, ordered: int}
     */
    public function validate(int $purchaseOrderLineId, int $shippedQuantity, ?int $excludeShipmentLineId = null): array
    {
        $poLine = PurchaseOrderLine::findOrFail($purchaseOrderLineId);
        $orderedQuantity = (int) $poLine->quantity;

        // Sum all shipped quantities for this PO line across all shipments
        $query = ShipmentLine::where('purchase_order_line_id', $purchaseOrderLineId);

        if ($excludeShipmentLineId) {
            $query->where('id', '!=', $excludeShipmentLineId);
        }

        $totalAlreadyShipped = (int) $query->sum('shipped_quantity');
        $totalAfterShipment = $totalAlreadyShipped + $shippedQuantity;
        $remaining = $orderedQuantity - $totalAlreadyShipped;

        if ($totalAfterShipment > $orderedQuantity) {
            return [
                'valid' => false,
                'message' => "Cannot ship {$shippedQuantity} units. Only {$remaining} remaining out of {$orderedQuantity} ordered.",
                'remaining' => $remaining,
                'total_shipped' => $totalAlreadyShipped,
                'ordered' => $orderedQuantity,
            ];
        }

        return [
            'valid' => true,
            'message' => "Shipment quantity is valid. {$remaining} units were remaining, shipping {$shippedQuantity}.",
            'remaining' => $remaining - $shippedQuantity,
            'total_shipped' => $totalAfterShipment,
            'ordered' => $orderedQuantity,
        ];
    }

    /**
     * Get shipment progress for a specific PO line.
     *
     * @param int $purchaseOrderLineId
     * @return array{percentage: float, shipped: int, ordered: int, remaining: int}
     */
    public function getLineProgress(int $purchaseOrderLineId): array
    {
        $poLine = PurchaseOrderLine::findOrFail($purchaseOrderLineId);
        $ordered = (int) $poLine->quantity;
        $shipped = (int) ShipmentLine::where('purchase_order_line_id', $purchaseOrderLineId)
            ->sum('shipped_quantity');

        return [
            'percentage' => $ordered > 0 ? round(($shipped / $ordered) * 100, 1) : 0,
            'shipped' => $shipped,
            'ordered' => $ordered,
            'remaining' => max(0, $ordered - $shipped),
        ];
    }

    /**
     * Get overall shipment progress for an entire Purchase Order.
     *
     * @param int $purchaseOrderId
     * @return array{percentage: float, lines: array}
     */
    public function getPurchaseOrderProgress(int $purchaseOrderId): array
    {
        $poLines = PurchaseOrderLine::where('purchase_order_id', $purchaseOrderId)->get();

        if ($poLines->isEmpty()) {
            return ['percentage' => 0, 'lines' => []];
        }

        $totalOrdered = 0;
        $totalShipped = 0;
        $lines = [];

        foreach ($poLines as $poLine) {
            $progress = $this->getLineProgress($poLine->id);
            $totalOrdered += $progress['ordered'];
            $totalShipped += $progress['shipped'];
            $lines[$poLine->id] = $progress;
        }

        return [
            'percentage' => $totalOrdered > 0 ? round(($totalShipped / $totalOrdered) * 100, 1) : 0,
            'lines' => $lines,
        ];
    }
}
