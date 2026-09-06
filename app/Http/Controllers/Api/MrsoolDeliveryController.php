<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\ResolvesZooboxiWarehouses;
use App\Http\Controllers\Controller;
use App\Http\Resources\MrsoolDeliveryResource;
use App\Services\Mrsool\MrsoolDeliveryService;
use App\Services\Mrsool\MrsoolException;
use App\Services\Mrsool\MrsoolNotEligibleException;
use Illuminate\Http\Request;

/**
 * The branch manager's Mrsool (مرسول) surface: see whether a courier can be
 * requested for an express order, get a price, request one, and pull it back.
 *
 * Scoped to the manager's own branch through ResolvesZooboxiWarehouses — the
 * same warehouse resolution the order endpoints use.
 */
class MrsoolDeliveryController extends Controller
{
    use ResolvesZooboxiWarehouses;

    // Re-sync from Mrsool when the cached state is older than this.
    private const STALE_SECONDS = 45;

    public function __construct(private MrsoolDeliveryService $mrsool)
    {
    }

    /**
     * GET /zooboxi-orders/{id}/mrsool — eligibility + the live delivery card.
     */
    public function show(Request $request, int $id)
    {
        $order = $this->scopedZooboxiOrders($request->user())->findOrFail($id);

        $delivery = $this->mrsool->activeDelivery($order) ?: $this->mrsool->latestDelivery($order);

        // Refresh a stale ACTIVE delivery before answering (best-effort).
        if ($delivery && !$delivery->isTerminal()
            && (!$delivery->last_synced_at || $delivery->last_synced_at->lt(now()->subSeconds(self::STALE_SECONDS)))) {
            try {
                $this->mrsool->sync($delivery);
                $delivery->refresh();
            } catch (\Throwable $e) {
                // Stale data is better than a failed screen.
            }
        }

        return response()->json([
            'eligible' => $this->mrsool->eligibility($order->refresh()),
            'delivery' => $delivery ? new MrsoolDeliveryResource($delivery) : null,
        ]);
    }

    /**
     * GET /zooboxi-orders/{id}/mrsool/quote — indicative delivery price.
     */
    public function quote(Request $request, int $id)
    {
        $order = $this->scopedZooboxiOrders($request->user())->findOrFail($id);

        return response()->json([
            'price'    => $this->mrsool->quote($order),
            'currency' => 'SAR',
        ]);
    }

    /**
     * POST /zooboxi-orders/{id}/mrsool/request — ask Mrsool for a courier.
     */
    public function request(Request $request, int $id)
    {
        $order = $this->scopedZooboxiOrders($request->user())->with('lines')->findOrFail($id);

        try {
            $delivery = $this->mrsool->requestCourier($order, $request->user());
        } catch (MrsoolException $e) {
            // Mrsool itself rejected the create — upstream failure.
            return response()->json(['message' => $e->getMessage()], 502);
        } catch (MrsoolNotEligibleException $e) {
            // One of our own guards said no.
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['delivery' => new MrsoolDeliveryResource($delivery)], 201);
    }

    /**
     * POST /zooboxi-orders/{id}/mrsool/cancel — pull the request back.
     */
    public function cancel(Request $request, int $id)
    {
        $order = $this->scopedZooboxiOrders($request->user())->findOrFail($id);

        $delivery = $this->mrsool->activeDelivery($order);
        if (!$delivery) {
            return response()->json(['message' => 'لا يوجد طلب مندوب قائم لهذا الطلب.'], 422);
        }

        try {
            $delivery = $this->mrsool->cancel($delivery, $request->user());
        } catch (MrsoolException $e) {
            return response()->json(['message' => $e->getMessage()], 502);
        } catch (MrsoolNotEligibleException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['delivery' => new MrsoolDeliveryResource($delivery)]);
    }
}
