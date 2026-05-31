<?php

namespace App\Services;

use App\Models\Supplier;
use App\Models\User;
use Illuminate\Support\Facades\Notification;
use Illuminate\Notifications\Messages\MailMessage;

class ContractAlertService
{
    /**
     * Check for expiring contracts and send alerts.
     *
     * @param array $thresholdDays Days before expiry to send alerts (default: 30, 15, 7)
     * @return array Summary of alerts sent
     */
    public function checkExpiringContracts(array $thresholdDays = [30, 15, 7]): array
    {
        $results = [];

        foreach ($thresholdDays as $days) {
            $targetDate = now()->addDays($days)->format('Y-m-d');

            $expiringSuppliers = Supplier::whereNotNull('end_date')
                ->whereDate('end_date', $targetDate)
                ->with('accountManager')
                ->get();

            foreach ($expiringSuppliers as $supplier) {
                $this->sendContractAlert($supplier, $days);
                $results[] = [
                    'supplier_id' => $supplier->id,
                    'supplier_name' => $supplier->name,
                    'end_date' => $supplier->end_date,
                    'days_remaining' => $days,
                ];
            }
        }

        return $results;
    }

    /**
     * Get all suppliers with contracts expiring within the given number of days.
     *
     * @param int $withinDays
     * @return \Illuminate\Database\Eloquent\Collection
     */
    public function getExpiringContracts(int $withinDays = 30)
    {
        return Supplier::whereNotNull('end_date')
            ->where('end_date', '<=', now()->addDays($withinDays))
            ->where('end_date', '>=', now())
            ->with('accountManager')
            ->orderBy('end_date')
            ->get();
    }

    /**
     * Get count of expired contracts (past due).
     *
     * @return int
     */
    public function getExpiredContractsCount(): int
    {
        return Supplier::whereNotNull('end_date')
            ->where('end_date', '<', now())
            ->count();
    }

    /**
     * Send a contract expiry alert to the account manager and admin users.
     *
     * @param Supplier $supplier
     * @param int $daysRemaining
     */
    protected function sendContractAlert(Supplier $supplier, int $daysRemaining): void
    {
        // Collect recipients: Account Manager + Super Admin users
        $recipients = collect();

        if ($supplier->accountManager) {
            $recipients->push($supplier->accountManager);
        }

        // Add Super Admin users
        $admins = User::role('Super Admin')->get();
        $recipients = $recipients->merge($admins)->unique('id');

        if ($recipients->isEmpty()) {
            return;
        }

        // Send database notification (Filament bell icon)
        foreach ($recipients as $recipient) {
            $recipient->notify(new \App\Notifications\ContractExpiryAlert(
                $supplier,
                $daysRemaining
            ));
        }
    }
}
