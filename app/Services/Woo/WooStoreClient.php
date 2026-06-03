<?php

namespace App\Services\Woo;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Outbound client to the WooCommerce store REST API.
 *
 * Used to push order-status changes back to the store (e.g. when a branch
 * manager finishes preparing an express order, the order moves to the custom
 * "zb-ready" status). Credentials live in config/services.php (`services.woo`).
 *
 * Pushes are best-effort: failures are logged and reported to the caller, never
 * thrown — the local fulfillment state is the source of truth and a failed push
 * can be retried later (woo_status_synced_at stays null).
 */
class WooStoreClient
{
    /**
     * Set a WooCommerce order's status via PUT /wc/v3/orders/{id}.
     *
     * @param  string  $status  WooCommerce status slug WITHOUT the wc- prefix
     *                           (e.g. 'zb-ready', 'completed').
     * @return bool  Whether the store accepted the change.
     */
    public function setOrderStatus(int $wooOrderId, string $status = 'zb-ready'): bool
    {
        $storeUrl = rtrim((string) config('services.woo.store_url'), '/');
        $key = config('services.woo.consumer_key');
        $secret = config('services.woo.consumer_secret');

        if (!$storeUrl || !$key || !$secret) {
            Log::warning('WooStoreClient: missing store URL / consumer credentials; status push skipped', [
                'woo_order_id' => $wooOrderId,
                'status' => $status,
            ]);
            return false;
        }

        try {
            $response = Http::withBasicAuth($key, $secret)
                ->acceptJson()
                ->timeout(15)
                ->put("{$storeUrl}/wp-json/wc/v3/orders/{$wooOrderId}", [
                    'status' => $status,
                ]);

            if ($response->successful()) {
                return true;
            }

            Log::warning('WooStoreClient: store rejected status update', [
                'woo_order_id' => $wooOrderId,
                'status' => $status,
                'http_status' => $response->status(),
                'body' => $response->body(),
            ]);
            return false;
        } catch (\Throwable $e) {
            Log::warning('WooStoreClient: status update failed: ' . $e->getMessage(), [
                'woo_order_id' => $wooOrderId,
                'status' => $status,
            ]);
            return false;
        }
    }
}
