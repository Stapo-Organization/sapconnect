<?php

namespace App\Services;

use App\Models\PaymentAlert;
use App\Models\PurchaseOrder;
use App\Models\PurchaseOrderLine;
use App\Models\ShipmentLine;

class PurchaseOrderAnalytics
{
    /**
     * Get comprehensive analytics for a Purchase Order.
     *
     * @param PurchaseOrder $po
     * @return array
     */
    public function getAnalytics(PurchaseOrder $po): array
    {
        return [
            'total_value' => $this->calculateTotalValue($po),
            'shipment_progress' => $this->getShipmentProgress($po),
            'payment_summary' => $this->getPaymentSummary($po),
            'shipment_count' => $po->shipments()->count(),
        ];
    }

    /**
     * Calculate total PO value from line items.
     *
     * @param PurchaseOrder $po
     * @return float
     */
    public function calculateTotalValue(PurchaseOrder $po): float
    {
        return (float) $po->lines()->sum('total_price');
    }

    /**
     * Get shipment progress as percentage.
     *
     * @param PurchaseOrder $po
     * @return array{percentage: float, total_ordered: int, total_shipped: int}
     */
    public function getShipmentProgress(PurchaseOrder $po): array
    {
        $poLineIds = $po->lines()->pluck('id');
        $totalOrdered = (int) $po->lines()->sum('quantity');
        $totalShipped = (int) ShipmentLine::whereIn('purchase_order_line_id', $poLineIds)
            ->sum('shipped_quantity');

        return [
            'percentage' => $totalOrdered > 0 ? round(($totalShipped / $totalOrdered) * 100, 1) : 0,
            'total_ordered' => $totalOrdered,
            'total_shipped' => $totalShipped,
        ];
    }

    /**
     * Get payment summary for a Purchase Order.
     *
     * @param PurchaseOrder $po
     * @return array{total_due: float, total_paid: float, total_pending: float, total_overdue: float, alerts: \Illuminate\Database\Eloquent\Collection}
     */
    public function getPaymentSummary(PurchaseOrder $po): array
    {
        $alerts = PaymentAlert::where('purchase_order_id', $po->id)->get();

        return [
            'total_due' => (float) $alerts->sum('due_amount'),
            'total_paid' => (float) $alerts->where('status', 'paid')->sum('due_amount'),
            'total_pending' => (float) $alerts->where('status', 'pending')->sum('due_amount'),
            'total_overdue' => (float) $alerts->where('status', 'overdue')->sum('due_amount'),
            'alerts' => $alerts,
        ];
    }

    /**
     * Get summary stats across all active POs.
     *
     * @return array
     */
    public function getGlobalStats(): array
    {
        $activePOs = PurchaseOrder::where('sync_status', '!=', 'synced')
            ->orWhereNull('sync_status')
            ->count();

        $totalPendingPayments = PaymentAlert::where('status', 'pending')->sum('due_amount');
        $totalOverduePayments = PaymentAlert::where('status', 'overdue')->sum('due_amount');

        return [
            'active_pos' => $activePOs,
            'total_pending_payments' => (float) $totalPendingPayments,
            'total_overdue_payments' => (float) $totalOverduePayments,
        ];
    }
}
