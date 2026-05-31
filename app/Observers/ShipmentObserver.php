<?php

namespace App\Observers;

use App\Models\PaymentAlert;
use App\Models\Shipment;
use App\Models\User;
use App\Notifications\FinancePaymentAlert;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Notification;

class ShipmentObserver
{
    /**
     * Map shipment statuses to payment policy conditions.
     */
    protected array $statusConditionMap = [
        'shipped'            => 'on_shipment',
        'in_transit'         => 'on_shipment',
        'arrived_port'       => 'on_arrival',
        'clearance'          => 'on_clearance',
        'received_warehouse' => 'on_clearance',
        'delivered'          => 'on_clearance',
    ];

    /**
     * Handle the Shipment "updated" event.
     */
    public function updated(Shipment $shipment): void
    {
        if ($shipment->wasChanged('status')) {
            $this->processPaymentAlerts($shipment);
        }
    }

    /**
     * Process payment alerts based on shipment status change.
     */
    protected function processPaymentAlerts(Shipment $shipment): void
    {
        $condition = $this->statusConditionMap[$shipment->status] ?? null;
        if (!$condition) {
            return;
        }

        $po = $shipment->purchaseOrder;
        if (!$po) {
            return;
        }

        $policy = $po->paymentPolicy;
        if (!$policy) {
            return;
        }

        // Find matching payment policy lines
        $policyLines = $policy->lines()->where('condition', $condition)->get();

        if ($policyLines->isEmpty()) {
            return;
        }

        // Calculate PO Total (SUM of all line totals)
        $poTotal = $po->lines()->sum('total_price');

        // Get finance users for notification
        $financeUsers = $this->getFinanceUsers();

        foreach ($policyLines as $line) {
            $dueAmount = ($poTotal * $line->percentage) / 100;
            $dueDate = now()->addDays($line->due_days)->format('Y-m-d');

            // Log the alert in payment_alerts table
            $paymentAlert = PaymentAlert::create([
                'shipment_id' => $shipment->id,
                'purchase_order_id' => $po->id,
                'payment_policy_line_id' => $line->id,
                'due_amount' => $dueAmount,
                'due_date' => $dueDate,
                'status' => 'pending',
            ]);

            // Send notification (mail + database/Filament bell)
            Notification::send($financeUsers, new FinancePaymentAlert(
                $shipment,
                $po,
                $line,
                $dueAmount,
                $dueDate
            ));

            Log::info("Payment alert created", [
                'alert_id' => $paymentAlert->id,
                'shipment_id' => $shipment->id,
                'po_id' => $po->id,
                'condition' => $condition,
                'due_amount' => $dueAmount,
                'due_date' => $dueDate,
            ]);
        }
    }

    /**
     * Get users who should receive finance notifications.
     */
    protected function getFinanceUsers()
    {
        // If Spatie permissions/roles are present, get finance users
        $financeUsers = User::role(['Finance', 'Super Admin'])->get();

        // Fallback to first admin if no specific role exists
        if ($financeUsers->isEmpty()) {
            $financeUsers = User::where('id', 1)->get();
        }

        return $financeUsers;
    }
}

