<?php

namespace App\Observers;

use App\Models\Shipment;
use App\Models\User;
use App\Notifications\FinancePaymentAlert;
use Illuminate\Support\Facades\Notification;

class ShipmentObserver
{
    /**
     * Handle the Shipment "updated" event.
     */
    public function updated(Shipment $shipment): void
    {
        if ($shipment->wasChanged('status')) {
            // Map shipment status to payment policy condition
            $statusConditionMap = [
                'shipped' => 'on_shipment',
                'arrived_port' => 'on_arrival',
                'delivered' => 'on_clearance',
            ];

            $condition = $statusConditionMap[$shipment->status] ?? null;
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

            if ($policyLines->isNotEmpty()) {
                // Calculate PO Total (SUM of all line totals)
                $poTotal = $po->lines()->sum('total_price');

                // If Spatie permissions/roles are present, get finance users. 
                // Alternatively, fallback to super admin or specified emails.
                $financeUsers = User::role(['Finance', 'Super Admin'])->get();
                
                // If no specific role exists yet, get first admin
                if ($financeUsers->isEmpty()) {
                    $financeUsers = User::where('id', 1)->get();
                }

                foreach ($policyLines as $line) {
                    $dueAmount = ($poTotal * $line->percentage) / 100;
                    $dueDate = now()->addDays($line->due_days)->format('Y-m-d');

                    // Send alert to Finance
                    Notification::send($financeUsers, new FinancePaymentAlert(
                        $shipment, 
                        $po, 
                        $line, 
                        $dueAmount, 
                        $dueDate
                    ));
                }
            }
        }
    }
}
