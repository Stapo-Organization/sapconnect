<?php

namespace App\Services;

use App\Models\User;
use App\Services\SMS\TaqnyatService;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    protected $smsService;

    public function __construct()
    {
        $this->smsService = new TaqnyatService();
    }

    /**
     * Notify all users associated with a specific warehouse.
     */
    public function notifyWarehouseUsers(string $warehouseCode, string $title, string $body, array $data = []): void
    {
        $users = User::where(function ($q) use ($warehouseCode) {
            // warehouse_code can be a JSON array or a string
            $q->whereJsonContains('warehouse_code', $warehouseCode)
              ->orWhere('warehouse_code', $warehouseCode);
        })->get();

        if ($users->isEmpty()) {
            Log::info("NotificationService: No users found for warehouse {$warehouseCode}");
            return;
        }

        // Send SMS
        $mobileNumbers = $users->whereNotNull('mobile_number')
            ->pluck('mobile_number')
            ->toArray();

        if (!empty($mobileNumbers)) {
            try {
                $smsMessage = "{$title}\n{$body}";
                $this->smsService->sendSms($mobileNumbers, $smsMessage);
                Log::info("NotificationService: SMS sent to " . count($mobileNumbers) . " users for warehouse {$warehouseCode}");
            } catch (\Exception $e) {
                Log::error("NotificationService: SMS failed: " . $e->getMessage());
            }
        }

        // FCM Push (placeholder for future Firebase setup)
        $fcmTokens = $users->whereNotNull('fcm_token')
            ->pluck('fcm_token')
            ->toArray();

        if (!empty($fcmTokens)) {
            try {
                $this->sendFcmNotification($fcmTokens, $title, $body, $data);
            } catch (\Exception $e) {
                Log::error("NotificationService: FCM failed: " . $e->getMessage());
            }
        }
    }

    /**
     * Send FCM push notification (placeholder).
     */
    protected function sendFcmNotification(array $tokens, string $title, string $body, array $data = []): void
    {
        Log::info("NotificationService: FCM notification queued", [
            'tokens_count' => count($tokens),
            'title' => $title,
        ]);
        // TODO: Implement via Firebase Admin SDK when configured
    }
}
