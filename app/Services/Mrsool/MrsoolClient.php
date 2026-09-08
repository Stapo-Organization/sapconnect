<?php

namespace App\Services\Mrsool;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * HTTP client for the Mrsool LaaS API (مرسول — التوصيل كخدمة).
 *
 * Mirrors the house style of App\Services\Traqo\TraqoClient (Laravel Http
 * facade, config-based credentials, base URL + timeout from config) with ONE
 * deliberate difference: this API is a WRITE integration, so a rejected call
 * throws MrsoolException instead of degrading silently — the caller must know
 * whether a courier was actually requested.
 *
 * Auth: `Authorization: Bearer <API_KEY>` + `locale: ar` so error messages come
 * back in Arabic. The API key is NEVER logged.
 */
class MrsoolClient
{
    protected string $baseUrl;
    protected ?string $apiKey;
    protected int $timeout;

    /** Set only for the duration of a withTimeout() call. */
    protected ?int $liveTimeout = null;

    public function __construct()
    {
        $this->baseUrl = rtrim((string) config('services.mrsool.base_url'), '/');
        $this->apiKey  = config('services.mrsool.api_key');
        $this->timeout = (int) config('services.mrsool.timeout', 20);
    }

    public function configured(): bool
    {
        return $this->baseUrl !== '' && !empty($this->apiKey);
    }

    /** 'staging' or 'production' — recorded on every ledger row. */
    public function environment(): string
    {
        return str_contains($this->baseUrl, 'staging') ? 'staging' : 'production';
    }

    /**
     * Delivery price for a pickup → dropoff pair.
     *
     * Returns null when Mrsool cannot quote (e.g. 422 «لم يتم تحديد إعدادات
     * الأسعار للمتجر») — an unavailable quote is informational, never fatal.
     *
     * @param  array{latitude: float|string, longitude: float|string}  $pickup
     * @param  array{latitude: float|string, longitude: float|string}  $dropoff
     */
    public function quote(array $pickup, array $dropoff): ?float
    {
        if (!$this->configured()) {
            return null;
        }

        try {
            $response = $this->request()->post($this->baseUrl . '/api/v1/orders/calculate_price', [
                'pickup'  => $this->coords($pickup),
                'dropoff' => $this->coords($dropoff),
            ]);

            if (!$response->successful()) {
                Log::info('mrsool: quote unavailable', [
                    'context' => 'mrsool',
                    'status'  => $response->status(),
                    'body'    => $response->json() ?? $response->body(),
                ]);
                return null;
            }

            // The API returns the price as a string in `data`.
            $price = $response->json('data');
            return is_numeric($price) ? (float) $price : null;
        } catch (\Throwable $e) {
            Log::info('mrsool: quote failed: ' . $e->getMessage(), ['context' => 'mrsool']);
            return null;
        }
    }

    /** Create a delivery order. Returns the Order payload. */
    public function createOrder(array $payload): array
    {
        return $this->send('post', '/api/v1/orders', $payload);
    }

    /** Fetch one order by its Mrsool id. */
    public function getOrder(int $id): array
    {
        return $this->send('get', "/api/v1/orders/{$id}");
    }

    /** Cancel an order (422 when it is no longer cancellable). */
    public function cancel(int $id): array
    {
        return $this->send('post', "/api/v1/orders/{$id}/cancel");
    }

    /** Air-waybill PDF URL, or null when the API does not expose one yet. */
    public function airWaybill(int $id): ?string
    {
        try {
            $data = $this->send('get', "/api/v1/orders/{$id}/air_waybill");
        } catch (MrsoolException $e) {
            Log::info('mrsool: air waybill unavailable: ' . $e->getMessage(), [
                'context'  => 'mrsool',
                'order_id' => $id,
            ]);
            return null;
        }

        foreach (['url', 'air_waybill', 'air_waybill_url', 'pdf_url', 'link'] as $key) {
            if (!empty($data[$key]) && is_string($data[$key])) {
                return $data[$key];
            }
        }

        return null;
    }

    /**
     * Drive an order's status on STAGING (also fires the real webhook).
     * Refuses to run against production — this is a test-only hook.
     */
    public function testStatus(int $id, string $status): array
    {
        if ($this->environment() !== 'staging') {
            throw new MrsoolException('لا يمكن تغيير الحالة يدوياً إلا في بيئة الاختبار.', 400);
        }

        return $this->send('post', "/api/v1/orders/{$id}/test_status", ['status' => $status]);
    }

    /** Staging webhook delivery log (debug aid). */
    public function webhookLogs(?int $orderId = null): array
    {
        return $this->send('get', '/api/v1/webhook_logs', $orderId ? ['order_id' => $orderId] : []);
    }

    // ─── Internals ──────────────────────────────────────────────

    /**
     * Issue a call and return the unwrapped payload.
     *
     * Mrsool wraps successful responses in `data`; some endpoints do not — we
     * handle both. Non-2xx throws MrsoolException with the Arabic API message.
     */
    protected function send(string $method, string $path, array $body = []): array
    {
        if (!$this->configured()) {
            throw new MrsoolException('تكامل مرسول غير مهيّأ (مفتاح الواجهة مفقود).', 0);
        }

        try {
            $request = $this->request();
            $response = $method === 'get'
                ? $request->get($this->baseUrl . $path, $body)
                : $request->post($this->baseUrl . $path, $body);
        } catch (\Throwable $e) {
            Log::warning('mrsool: request failed: ' . $e->getMessage(), [
                'context' => 'mrsool',
                'path'    => $path,
            ]);
            throw new MrsoolException('تعذّر الاتصال بمرسول. حاول مرة أخرى.', 0);
        }

        $json = $response->json() ?? [];

        if (!$response->successful()) {
            $errors  = is_array($json['errors'] ?? null) ? $json['errors'] : [];
            $message = $errors[0]['message'] ?? ($json['message'] ?? null);
            $message = is_string($message) && $message !== ''
                ? $message
                : 'رفضت مرسول الطلب (رمز ' . $response->status() . ').';

            // Body is logged for diagnosis; the API key never is.
            Log::warning('mrsool: request rejected', [
                'context' => 'mrsool',
                'path'    => $path,
                'status'  => $response->status(),
                'body'    => $json ?: $response->body(),
            ]);

            throw new MrsoolException($message, $response->status(), $errors);
        }

        Log::info('mrsool: ' . strtoupper($method) . ' ' . $path . ' ok', [
            'context' => 'mrsool',
            'status'  => $response->status(),
        ]);

        $data = $json['data'] ?? $json;

        return is_array($data) ? $data : ['data' => $data];
    }

    protected function request()
    {
        return Http::withToken((string) $this->apiKey)
            ->withHeaders(['locale' => 'ar'])
            ->acceptJson()
            ->asJson()
            ->timeout($this->liveTimeout ?? $this->timeout);
    }

    /**
     * Run one call under a tighter deadline.
     *
     * The default 20s is right for requesting a courier — that call must not be
     * abandoned halfway. It is far too long for a customer refreshing a map,
     * where the caller sits inside a store request that itself has seconds to
     * live, and a stale position beats a spinner.
     */
    public function withTimeout(int $seconds, callable $fn): mixed
    {
        $previous = $this->liveTimeout;
        $this->liveTimeout = max(1, $seconds);

        try {
            return $fn($this);
        } finally {
            $this->liveTimeout = $previous;
        }
    }

    /**
     * Mrsool expects latitude/longitude as STRINGS — casting floats keeps the
     * decimals intact and avoids locale-dependent float serialisation.
     */
    protected function coords(array $point): array
    {
        return [
            'latitude'  => (string) $point['latitude'],
            'longitude' => (string) $point['longitude'],
        ];
    }
}
