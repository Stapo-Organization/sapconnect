<?php

namespace App\Services\Woo;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Outbound client to the Zooboxi WooCommerce store.
 *
 * Pushes order-status changes back to the store (e.g. when a branch manager
 * finishes preparing an express order, the order moves to the custom
 * "zb-ready" status).
 *
 * We call a dedicated plugin endpoint (zooboxi/v1/orders/{id}/status)
 * authenticated with the shared token sent IN THE BODY — this is immune to the
 * server stripping the Authorization header (which breaks WooCommerce core's
 * Basic-Auth REST API on this host) and runs $order->update_status() with full
 * capabilities so all status hooks/emails fire. Credentials live in
 * config/services.php (`services.woo`).
 *
 * Pushes are best-effort: failures are logged and reported to the caller, never
 * thrown — local fulfillment state is the source of truth and a failed push can
 * be retried later (woo_status_synced_at stays null).
 */
class WooStoreClient
{
    /**
     * Set a WooCommerce order's status via the Zooboxi plugin endpoint.
     *
     * @param  string  $status  WooCommerce status slug WITHOUT the wc- prefix
     *                           (e.g. 'zb-ready', 'completed').
     * @return bool  Whether the store accepted the change.
     */
    public function setOrderStatus(int $wooOrderId, string $status = 'zb-ready'): bool
    {
        $storeUrl = rtrim((string) config('services.woo.store_url'), '/');
        $token = (string) config('services.woo.api_token');

        if (!$storeUrl || !$token) {
            Log::warning('WooStoreClient: missing store URL / api token; status push skipped', [
                'woo_order_id' => $wooOrderId,
                'status' => $status,
            ]);
            return false;
        }

        try {
            $response = Http::acceptJson()
                ->timeout(20)
                ->post("{$storeUrl}/wp-json/zooboxi/v1/orders/{$wooOrderId}/status", [
                    'status' => $status,
                    'token' => $token,
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
