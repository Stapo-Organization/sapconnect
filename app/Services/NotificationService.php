<?php

namespace App\Services;

use App\Models\DeviceToken;
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
     * Push-only notification to a warehouse's users (no SMS — used for
     * cycle-count reminders to avoid SMS cost). Collects multi-device tokens
     * from device_tokens, falling back to the legacy users.fcm_token.
     */
    public function pushToWarehouseUsers(string $warehouseCode, string $title, string $body, array $data = []): void
    {
        $userIds = User::where(function ($q) use ($warehouseCode) {
            $q->whereJsonContains('warehouse_code', $warehouseCode)
              ->orWhere('warehouse_code', $warehouseCode);
        })->pluck('id');

        if ($userIds->isEmpty()) {
            return;
        }

        $tokens = DeviceToken::whereIn('user_id', $userIds)->pluck('token')->all();
        if (empty($tokens)) {
            $tokens = User::whereIn('id', $userIds)->whereNotNull('fcm_token')->pluck('fcm_token')->all();
        }

        if (empty($tokens)) {
            Log::info("NotificationService: no device tokens for warehouse {$warehouseCode}");
            return;
        }

        $this->sendFcmNotification(array_values(array_unique($tokens)), $title, $body, $data);
    }

    /**
     * Send an FCM push. Inert (logs and returns) until Firebase is configured
     * via kreait/laravel-firebase + FIREBASE_CREDENTIALS, so it is safe to
     * deploy and schedule before the Firebase project exists.
     */
    protected function sendFcmNotification(array $tokens, string $title, string $body, array $data = []): void
    {
        if (!class_exists(\Kreait\Firebase\Factory::class)) {
            Log::info('NotificationService: Firebase not installed; FCM skipped', [
                'tokens_count' => count($tokens),
                'title' => $title,
            ]);
            return;
        }

        try {
            /** @var \Kreait\Firebase\Contract\Messaging $messaging */
            $messaging = app(\Kreait\Firebase\Contract\Messaging::class);

            $message = \Kreait\Firebase\Messaging\CloudMessage::new()
                ->withNotification(\Kreait\Firebase\Messaging\Notification::create($title, $body))
                ->withData(array_map(fn ($v) => (string) $v, $data));

            $report = $messaging->sendMulticast($message, $tokens);

            // Prune tokens Firebase reports as unknown/invalid.
            if (method_exists($report, 'invalidTokens')) {
                $invalid = $report->invalidTokens();
                if (!empty($invalid)) {
                    DeviceToken::whereIn('token', $invalid)->delete();
                }
            }

            Log::info('NotificationService: FCM sent', ['tokens_count' => count($tokens)]);
        } catch (\Throwable $e) {
            Log::error('NotificationService: FCM send failed: ' . $e->getMessage());
        }
    }
}
