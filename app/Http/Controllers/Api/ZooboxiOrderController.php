<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Concerns\ResolvesZooboxiWarehouses;
use App\Http\Resources\ZooboxiOrderApiResource;
use App\Models\ZooboxiOrder;
use App\Services\Woo\WooStoreClient;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Express Zooboxi order fulfillment for branch managers.
 *
 * Surfaces the urgent (express) orders assigned to the manager's branch that
 * are not yet prepared, lets them mark an order as being prepared and then
 * "ready" — which also pushes the status to the WooCommerce store.
 */
class ZooboxiOrderController extends Controller
{
    use ResolvesZooboxiWarehouses;

    public function __construct(private WooStoreClient $store) {}

    // Eager-loaded on every order payload: lines for the picking list, the
    // warehouse + active Mrsool delivery for the courier card/map (avoids N+1).
    private const EAGER = ['lines', 'zooboxiWarehouse', 'activeMrsoolDelivery'];

    // Un-prepared = still actionable by the branch (the "waiting" tab).
    private const OPEN_STATUSES = [
        ZooboxiOrder::STATUS_PENDING,
        ZooboxiOrder::STATUS_PREPARING,
    ];

    // Prepared / handed off = the "done" tab.
    private const DONE_STATUSES = [
        ZooboxiOrder::STATUS_READY_FOR_PICKUP,
        ZooboxiOrder::STATUS_OUT_FOR_DELIVERY,
        ZooboxiOrder::STATUS_DELIVERED,
    ];

    /**
     * GET /zooboxi-orders/summary — Home badge + the next few orders.
     */
    public function summary(Request $request)
    {
        $codes = $this->resolveZooboxiWarehouseCodes($request->user());

        $base = $this->baseQuery($codes);
        $count = (clone $base)->count();
        $orders = $base->with(self::EAGER)->latest()->limit(10)->get();

        return response()->json([
            'urgent_count' => $count,
            'orders' => ZooboxiOrderApiResource::collection($orders),
        ]);
    }

    /**
     * GET /zooboxi-orders — express orders for the branch (un-prepared by default).
     */
    public function index(Request $request)
    {
        $codes = $this->resolveZooboxiWarehouseCodes($request->user());

        $query = ZooboxiOrder::query()
            ->byDeliveryType(ZooboxiOrder::DELIVERY_EXPRESS)
            ->with(self::EAGER)
            ->latest();

        $query->whereIn('warehouse_code', $codes ?: ['__none__']);

        if ($request->filled('status')) {
            $query->where('delivery_status', $request->status);
        } elseif ($request->get('scope') === 'done') {
            $query->whereIn('delivery_status', self::DONE_STATUSES);
        } else {
            $query->whereIn('delivery_status', self::OPEN_STATUSES);
        }

        return ZooboxiOrderApiResource::collection(
            $query->paginate($request->integer('per_page', 20))
        );
    }

    /**
     * GET /zooboxi-orders/{id} — one order with its lines.
     */
    public function show(Request $request, int $id)
    {
        $order = $this->scopedZooboxiOrders($request->user())->with(self::EAGER)->findOrFail($id);

        return new ZooboxiOrderApiResource($order);
    }

    /**
     * POST /zooboxi-orders/{id}/start — begin preparing (pending → preparing).
     * Local only; the meaningful WooCommerce push happens on prepare().
     */
    public function startPreparing(Request $request, int $id)
    {
        $order = $this->scopedZooboxiOrders($request->user())->findOrFail($id);

        if ($order->delivery_status !== ZooboxiOrder::STATUS_PENDING) {
            return response()->json([
                'message' => 'لا يمكن بدء تجهيز هذا الطلب في حالته الحالية.',
            ], 422);
        }

        $order->update(['delivery_status' => ZooboxiOrder::STATUS_PREPARING]);
        $order->load(self::EAGER);

        return new ZooboxiOrderApiResource($order);
    }

    /**
     * POST /zooboxi-orders/{id}/prepare — mark prepared (→ ready_for_pickup) and
     * push the "ready" status to the WooCommerce store.
     */
    public function markPrepared(Request $request, int $id)
    {
        $user = $request->user();
        $order = $this->scopedZooboxiOrders($user)->findOrFail($id);

        if (!in_array($order->delivery_status, self::OPEN_STATUSES, true)) {
            return response()->json([
                'message' => 'الطلب مجهّز مسبقاً.',
            ], 422);
        }

        $order->update([
            'delivery_status' => ZooboxiOrder::STATUS_READY_FOR_PICKUP,
            'prepared_by' => $user->id,
            'prepared_at' => now(),
        ]);

        // Push the "ready" status back to WooCommerce (best-effort).
        $wooSynced = $this->store->setOrderStatus($order->woo_order_id, 'zb-ready');
        if ($wooSynced) {
            $order->update(['woo_status_synced_at' => now()]);
        } else {
            Log::warning('Zooboxi order prepared but WooCommerce status not synced', [
                'order_id' => $order->id,
                'woo_order_id' => $order->woo_order_id,
            ]);
        }

        $order->load(self::EAGER);

        return response()->json([
            'data' => new ZooboxiOrderApiResource($order),
            'woo_synced' => $wooSynced,
        ]);
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Open express orders for the given Zooboxi warehouse codes.
     */
    private function baseQuery(array $codes)
    {
        return ZooboxiOrder::query()
            ->byDeliveryType(ZooboxiOrder::DELIVERY_EXPRESS)
            ->whereIn('delivery_status', self::OPEN_STATUSES)
            ->whereIn('warehouse_code', $codes ?: ['__none__']);
    }
}
