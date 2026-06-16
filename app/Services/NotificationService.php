<?php

namespace App\Services;

use App\Models\DeviceToken;
use App\Models\User;
use App\Services\SMS\TaqnyatService;
use Illuminate\Support\Facades\Cache;
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
     * Push to a specific set of users (resolved by preference/router), collecting
     * their device_tokens (falling back to the legacy users.fcm_token).
     *
     * @param  int[] $userIds
     * @return int   number of unique device tokens the push was sent to
     */
    public function pushToUsers(array $userIds, string $title, string $body, array $data = []): int
    {
        $userIds = array_values(array_unique(array_filter($userIds)));
        if (empty($userIds)) {
            return 0;
        }

        $tokens = DeviceToken::whereIn('user_id', $userIds)->pluck('token')->all();
        if (empty($tokens)) {
            $tokens = User::whereIn('id', $userIds)->whereNotNull('fcm_token')->pluck('fcm_token')->all();
        }

        $tokens = array_values(array_unique(array_filter($tokens)));
        if (empty($tokens)) {
            return 0;
        }

        $this->sendFcmNotification($tokens, $title, $body, $data);

        return count($tokens);
    }

    /**
     * Send an FCM push via the Firebase Cloud Messaging HTTP v1 API.
     *
     * Uses google/auth (service account → OAuth2 token, cached) + a direct
     * Guzzle POST per token. This avoids kreait's messaging auth middleware,
     * which fails to attach the token on some prod dependency resolutions.
     * Inert (logs and returns) until FIREBASE_CREDENTIALS points to a readable
     * service-account file, so it is safe before Firebase is configured.
     */
    protected function sendFcmNotification(array $tokens, string $title, string $body, array $data = []): void
    {
        $credPath = $this->firebaseCredentialsPath();
        if (!$credPath || !class_exists(\Google\Auth\Credentials\ServiceAccountCredentials::class)) {
            Log::info('NotificationService: Firebase not configured; FCM skipped', [
                'tokens_count' => count($tokens),
                'title' => $title,
            ]);
            return;
        }

        try {
            $sa = json_decode(file_get_contents($credPath), true);
            $projectId = $sa['project_id'] ?? null;
            if (!$projectId) {
                Log::error('NotificationService: project_id missing in Firebase credentials');
                return;
            }

            $accessToken = $this->firebaseAccessToken($sa);
            if (!$accessToken) {
                Log::error('NotificationService: could not mint Firebase access token');
                return;
            }

            $client = new \GuzzleHttp\Client(['timeout' => 15]);
            $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
            $stringData = array_map(fn ($v) => (string) $v, $data);

            $invalid = [];
            $sent = 0;
            foreach (array_values(array_unique($tokens)) as $tok) {
                try {
                    $client->post($url, [
                        'headers' => ['Authorization' => 'Bearer ' . $accessToken],
                        'json' => [
                            'message' => [
                                'token' => $tok,
                                'notification' => ['title' => $title, 'body' => $body],
                                'data' => $stringData,
                            ],
                        ],
                    ]);
                    $sent++;
                } catch (\GuzzleHttp\Exception\ClientException $ce) {
                    $status = $ce->getResponse() ? $ce->getResponse()->getStatusCode() : 0;
                    $respBody = $ce->getResponse() ? (string) $ce->getResponse()->getBody() : '';
                    // Token no longer valid for this app → prune it.
                    if ($status === 404 || str_contains($respBody, 'UNREGISTERED') || str_contains($respBody, 'INVALID_ARGUMENT')) {
                        $invalid[] = $tok;
                    } else {
                        Log::error('NotificationService: FCM send error ' . $status . ' ' . substr($respBody, 0, 200));
                    }
                }
            }

            if (!empty($invalid)) {
                DeviceToken::whereIn('token', $invalid)->delete();
            }

            Log::info('NotificationService: FCM sent', ['sent' => $sent, 'pruned' => count($invalid)]);
        } catch (\Throwable $e) {
            Log::error('NotificationService: FCM send failed: ' . $e->getMessage());
        }
    }

    /** Absolute path to the Firebase service-account JSON, or null if unset/missing. */
    protected function firebaseCredentialsPath(): ?string
    {
        $p = config('firebase.projects.app.credentials') ?: env('FIREBASE_CREDENTIALS');
        if (!$p) {
            return null;
        }
        if (!str_starts_with($p, '/')) {
            $p = base_path($p);
        }
        return is_file($p) ? $p : null;
    }

    /** Mint (and cache ~50 min) an OAuth2 access token for FCM from the service account. */
    protected function firebaseAccessToken(array $sa): ?string
    {
        $cached = Cache::get('fcm_oauth_access_token');
        if ($cached) {
            return $cached;
        }

        $creds = new \Google\Auth\Credentials\ServiceAccountCredentials(
            'https://www.googleapis.com/auth/firebase.messaging',
            $sa
        );
        $token = $creds->fetchAuthToken()['access_token'] ?? null;
        if ($token) {
            Cache::put('fcm_oauth_access_token', $token, 3000);
        }
        return $token;
    }
}
