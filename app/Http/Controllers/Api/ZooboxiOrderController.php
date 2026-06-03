<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ZooboxiOrderApiResource;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiWarehouse;
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
    public function __construct(private WooStoreClient $store) {}

    // Un-prepared = still actionable by the branch.
    private const OPEN_STATUSES = [
        ZooboxiOrder::STATUS_PENDING,
        ZooboxiOrder::STATUS_PREPARING,
    ];

    /**
     * GET /zooboxi-orders/summary — Home badge + the next few orders.
     */
    public function summary(Request $request)
    {
        $codes = $this->resolveZooboxiWarehouseCodes($request->user());

        $base = $this->baseQuery($codes);
        $count = (clone $base)->count();
        $orders = $base->with('lines')->latest()->limit(10)->get();

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
            ->with('lines')
            ->latest();

        $query->whereIn('warehouse_code', $codes ?: ['__none__']);

        if ($request->filled('status')) {
            $query->where('delivery_status', $request->status);
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
        $order = $this->scopedQuery($request->user())->with('lines')->findOrFail($id);

        return new ZooboxiOrderApiResource($order);
    }

    /**
     * POST /zooboxi-orders/{id}/start — begin preparing (pending → preparing).
     * Local only; the meaningful WooCommerce push happens on prepare().
     */
    public function startPreparing(Request $request, int $id)
    {
        $order = $this->scopedQuery($request->user())->findOrFail($id);

        if ($order->delivery_status !== ZooboxiOrder::STATUS_PENDING) {
            return response()->json([
                'message' => 'لا يمكن بدء تجهيز هذا الطلب في حالته الحالية.',
            ], 422);
        }

        $order->update(['delivery_status' => ZooboxiOrder::STATUS_PREPARING]);
        $order->load('lines');

        return new ZooboxiOrderApiResource($order);
    }

    /**
     * POST /zooboxi-orders/{id}/prepare — mark prepared (→ ready_for_pickup) and
     * push the "ready" status to the WooCommerce store.
     */
    public function markPrepared(Request $request, int $id)
    {
        $user = $request->user();
        $order = $this->scopedQuery($user)->findOrFail($id);

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

        $order->load('lines');

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

    /**
     * Query scoped to the orders the user's branch is allowed to act on.
     */
    private function scopedQuery($user)
    {
        $codes = $this->resolveZooboxiWarehouseCodes($user);

        return ZooboxiOrder::query()->whereIn('warehouse_code', $codes ?: ['__none__']);
    }

    /**
     * Resolve the Zooboxi warehouse codes for a manager.
     *
     * The user carries SAP warehouse codes; orders carry Zooboxi codes. We map
     * via ZooboxiWarehouse.sap_warehouse_codes and union with the raw SAP codes
     * so it works whether the codes are bridged or simply coincide.
     */
    private function resolveZooboxiWarehouseCodes($user): array
    {
        $sapCodes = $this->getUserWarehouseCodes($user);
        if (empty($sapCodes)) {
            return [];
        }

        $mapped = ZooboxiWarehouse::query()
            ->where(function ($q) use ($sapCodes) {
                foreach ($sapCodes as $code) {
                    $q->orWhereJsonContains('sap_warehouse_codes', $code);
                }
            })
            ->pluck('warehouse_code')
            ->all();

        return array_values(array_unique(array_merge($sapCodes, $mapped)));
    }

    /**
     * Decode the user's warehouse codes (JSON array or scalar).
     * Mirrors InventoryCountingController::getUserWarehouseCodes.
     */
    private function getUserWarehouseCodes($user): array
    {
        if (!$user || !$user->warehouse_code) {
            return [];
        }
        $codes = $user->warehouse_code;
        if (is_string($codes)) {
            $decoded = json_decode($codes, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $codes = $decoded;
            }
        }
        return is_array($codes) ? $codes : [$codes];
    }
}
