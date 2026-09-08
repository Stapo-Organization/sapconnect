<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MrsoolCustomerTrackingResource;
use App\Models\MrsoolDelivery;
use App\Models\ZooboxiOrder;
use App\Services\Mrsool\MrsoolDeliveryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

/**
 * Live courier tracking for the CUSTOMER, served to the Zooboxi store.
 *
 * The customer's app never talks to sapconnect — it talks to the store, and the
 * store proxies here with the WooCommerce token. So this endpoint is the one
 * place a courier's live position leaves the operations side, and it hands over
 * only the customer-safe view (MrsoolCustomerTrackingResource).
 *
 * Freshness vs. cost. The ledger is refreshed by mrsool:sync-active every
 * minute, which is fine for a status and far too slow for a dot on a map, so a
 * read of a LIVE delivery re-fetches from Mrsool. Three guards keep that from
 * becoming a stampede:
 *   1. an age floor (`services.mrsool.live_refresh_seconds`),
 *   2. a lock, so ten people watching one courier make one call, not ten,
 *   3. a backoff after a failure, so a Mrsool outage is not retried by every
 *      viewer every ten seconds.
 * The refresh also runs WITHOUT side effects: no store push, no branch
 * notification. A customer opening a screen must never fan out writes.
 */
class MrsoolTrackingController extends Controller
{
    /** How long a failed refresh keeps every viewer from trying again. */
    private const BACKOFF_SECONDS = 60;

    public function __construct(private MrsoolDeliveryService $mrsool)
    {
    }

    public function show(int $wooOrderId): JsonResponse
    {
        $order = ZooboxiOrder::where('woo_order_id', $wooOrderId)->first();

        if (!$order) {
            return response()->json(['data' => null]);
        }

        $delivery = $this->mrsool->viewableDelivery($order);

        if (!$delivery) {
            return response()->json(['data' => null]);
        }

        $this->refreshIfStale($delivery);

        $dropoff = $order->customer_latitude !== null && $order->customer_longitude !== null
            ? ['lat' => (float) $order->customer_latitude, 'lng' => (float) $order->customer_longitude]
            : null;

        return response()->json([
            'data' => (new MrsoolCustomerTrackingResource(
                $delivery->fresh(),
                $this->mrsool->warehouse($order),
                $dropoff,
            ))->toArray(request()),
        ]);
    }

    /** Re-fetch a live delivery when the ledger row has gone stale. Never throws. */
    private function refreshIfStale(MrsoolDelivery $delivery): void
    {
        if (in_array($delivery->phase, MrsoolDelivery::TERMINAL_PHASES, true)) {
            return;
        }

        $maxAge = (int) config('services.mrsool.live_refresh_seconds', 25);
        if ($maxAge <= 0) {
            return;
        }

        if ($delivery->last_synced_at && $delivery->last_synced_at->gt(now()->subSeconds($maxAge))) {
            return;
        }

        $backoffKey = "mrsool:live:backoff:{$delivery->id}";
        if (Cache::get($backoffKey)) {
            return;
        }

        // Whoever gets the lock does the call; everyone else is served the row
        // as it stands, which is at most a few seconds old.
        Cache::lock("mrsool:live:{$delivery->id}", 10)->get(function () use ($delivery, $backoffKey) {
            $delivery->refresh();

            if (!$this->mrsool->refreshForViewer($delivery)) {
                Cache::put($backoffKey, true, self::BACKOFF_SECONDS);
            }
        });
    }
}
