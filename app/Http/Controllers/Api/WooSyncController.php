<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiOrderLine;
use App\Models\ZooboxiSyncLog;
use App\Models\ZooboxiWarehouse;
use App\Services\Woo\WooDeliveryService;
use App\Services\Woo\WooStockService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * WooCommerce Sync Controller.
 *
 * Provides API endpoints for the Zooboxi WooCommerce plugin to:
 * - Pull products, stock, and prices from sapconnect
 * - Push orders from WooCommerce to sapconnect
 * - Check delivery options based on customer location
 */
class WooSyncController extends Controller
{
    public function __construct(
        private WooDeliveryService $deliveryService,
        private WooStockService $stockService,
    ) {}

    // ─── Products ───────────────────────────────────────────────

    /**
     * GET /api/woo/products
     *
     * Returns products flagged for WooCommerce sync (woo_sync = true).
     * Supports pagination and filtering by updated_since.
     */
    public function getProducts(Request $request): JsonResponse
    {
        $query = Product::wooSyncable()
            ->production()
            ->with('brand');

        // Optional: only products updated since a timestamp
        if ($request->has('updated_since')) {
            $query->where('updated_at', '>=', $request->updated_since);
        }

        // Optional: filter by brand
        if ($request->has('brand_code')) {
            $query->where('items_group_code', $request->brand_code);
        }

        $perPage = min($request->integer('per_page', 50), 100);
        $products = $query->paginate($perPage);

        $data = $products->getCollection()->map(function (Product $p) {
            return $this->formatProduct($p);
        });

        return response()->json([
            'data' => $data,
            'meta' => [
                'total' => $products->total(),
                'page' => $products->currentPage(),
                'per_page' => $products->perPage(),
                'last_page' => $products->lastPage(),
            ],
        ]);
    }

    /**
     * GET /api/woo/products/{item_code}
     *
     * Returns a single product with full details.
     */
    public function getProduct(string $itemCode): JsonResponse
    {
        $product = Product::where('item_code', $itemCode)
            ->production()
            ->with('brand')
            ->firstOrFail();

        return response()->json([
            'data' => $this->formatProduct($product),
        ]);
    }

    // ─── Stock ──────────────────────────────────────────────────

    /**
     * GET /api/woo/stock
     *
     * Returns stock levels for all WooCommerce-synced products
     * across all active Zooboxi warehouses.
     */
    public function getStock(): JsonResponse
    {
        $stock = $this->stockService->getAllStock();

        return response()->json([
            'data' => $stock,
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    /**
     * GET /api/woo/stock/{warehouse_code}
     *
     * Returns stock levels for a specific warehouse.
     */
    public function getWarehouseStock(string $warehouseCode): JsonResponse
    {
        $stock = $this->stockService->getWarehouseStock($warehouseCode);

        return response()->json([
            'data' => $stock,
            'warehouse_code' => $warehouseCode,
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    // ─── Prices ─────────────────────────────────────────────────

    /**
     * GET /api/woo/prices
     *
     * Returns prices for all WooCommerce-synced products.
     */
    public function getPrices(Request $request): JsonResponse
    {
        $query = Product::wooSyncable()->production();

        if ($request->has('updated_since')) {
            $query->where('updated_at', '>=', $request->updated_since);
        }

        $products = $query->get(['item_code', 'prices', 'updated_at']);

        $data = $products->map(fn(Product $p) => [
            'item_code' => $p->item_code,
            'prices' => $p->prices ?? [],
            'updated_at' => $p->updated_at?->toIso8601String(),
        ]);

        return response()->json([
            'data' => $data,
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    // ─── Warehouses ─────────────────────────────────────────────

    /**
     * GET /api/woo/warehouses
     *
     * Returns all active Zooboxi warehouses with GPS and delivery settings.
     */
    public function getWarehouses(): JsonResponse
    {
        $warehouses = ZooboxiWarehouse::active()->get();

        return response()->json([
            'data' => $warehouses->map(fn(ZooboxiWarehouse $wh) => [
                'warehouse_code' => $wh->warehouse_code,
                'display_name_ar' => $wh->display_name_ar,
                'display_name_en' => $wh->display_name_en,
                'city' => $wh->city,
                'address_ar' => $wh->address_ar,
                'address_en' => $wh->address_en,
                'latitude' => $wh->latitude,
                'longitude' => $wh->longitude,
                'express_radius_km' => $wh->express_radius_km,
                'is_central' => $wh->is_central,
                'is_main_hub' => $wh->is_main_hub,
                'is_pickup_enabled' => $wh->is_pickup_enabled,
                'working_hours' => $wh->working_hours,
                'phone' => $wh->phone,
                'is_open_now' => $wh->isOpenNow(),
            ]),
        ]);
    }

    // ─── Delivery Options ───────────────────────────────────────

    /**
     * POST /api/woo/delivery-options
     *
     * Detect available delivery options based on customer GPS location.
     */
    public function getDeliveryOptions(Request $request): JsonResponse
    {
        $request->validate([
            'latitude' => 'required|numeric',
            'longitude' => 'required|numeric',
            'items' => 'sometimes|array',
            'items.*.item_code' => 'required_with:items|string',
            'items.*.quantity' => 'required_with:items|numeric|min:0.01',
        ]);

        $options = $this->deliveryService->detectDeliveryOptions(
            $request->latitude,
            $request->longitude,
            $request->input('items', [])
        );

        return response()->json($options);
    }

    // ─── Orders ─────────────────────────────────────────────────

    /**
     * POST /api/woo/orders
     *
     * Receive a new order from WooCommerce.
     * Validates stock, deducts inventory, and creates the order locally.
     */
    public function receiveOrder(Request $request): JsonResponse
    {
        $request->validate([
            'woo_order_id' => 'required|integer|unique:zooboxi_orders,woo_order_id',
            'woo_order_number' => 'sometimes|string|max:50',
            'delivery_type' => 'required|in:express,same_day,shipping,pickup',
            'warehouse_code' => 'sometimes|string',
            'customer' => 'required|array',
            'customer.name' => 'sometimes|string',
            'customer.phone' => 'sometimes|string',
            'customer.email' => 'sometimes|email',
            'customer.latitude' => 'sometimes|numeric',
            'customer.longitude' => 'sometimes|numeric',
            'customer.city' => 'sometimes|string',
            'customer.address' => 'sometimes|string',
            'items' => 'required|array|min:1',
            'items.*.item_code' => 'required|string',
            'items.*.item_name' => 'sometimes|string',
            'items.*.quantity' => 'required|numeric|min:0.01',
            'items.*.unit_price' => 'required|numeric|min:0',
            'items.*.total_price' => 'required|numeric|min:0',
            'payment' => 'sometimes|array',
            'payment.method' => 'sometimes|string',
            'payment.status' => 'sometimes|in:pending,paid,refunded,failed',
            'totals' => 'sometimes|array',
        ]);

        try {
            $order = DB::transaction(function () use ($request) {
                $customer = $request->input('customer', []);
                $totals = $request->input('totals', []);
                $payment = $request->input('payment', []);

                // Determine the warehouse if not provided
                $warehouseCode = $request->warehouse_code;
                if (!$warehouseCode && isset($customer['latitude'], $customer['longitude'])) {
                    $warehouseCode = $this->deliveryService->determineFulfillmentWarehouse(
                        $request->delivery_type,
                        $customer['latitude'],
                        $customer['longitude'],
                        $request->items
                    );
                }

                // Create the order
                $order = ZooboxiOrder::create([
                    'woo_order_id' => $request->woo_order_id,
                    'woo_order_number' => $request->woo_order_number,
                    'warehouse_code' => $warehouseCode,
                    'delivery_type' => $request->delivery_type,
                    'delivery_status' => ZooboxiOrder::STATUS_PENDING,
                    'customer_latitude' => $customer['latitude'] ?? null,
                    'customer_longitude' => $customer['longitude'] ?? null,
                    'customer_city' => $customer['city'] ?? null,
                    'customer_name' => $customer['name'] ?? null,
                    'customer_phone' => $customer['phone'] ?? null,
                    'customer_email' => $customer['email'] ?? null,
                    'customer_address' => $customer['address'] ?? null,
                    'payment_method' => $payment['method'] ?? null,
                    'payment_status' => $payment['status'] ?? 'pending',
                    'subtotal' => $totals['subtotal'] ?? 0,
                    'delivery_fee' => $totals['delivery_fee'] ?? 0,
                    'tax_amount' => $totals['tax'] ?? 0,
                    'total_amount' => $totals['total'] ?? 0,
                ]);

                // Create order lines
                $stockItems = [];
                foreach ($request->items as $item) {
                    ZooboxiOrderLine::create([
                        'zooboxi_order_id' => $order->id,
                        'item_code' => $item['item_code'],
                        'item_name' => $item['item_name'] ?? null,
                        'warehouse_code' => $warehouseCode ?? '',
                        'quantity' => $item['quantity'],
                        'unit_price' => $item['unit_price'],
                        'total_price' => $item['total_price'],
                    ]);

                    if ($warehouseCode) {
                        $stockItems[] = [
                            'item_code' => $item['item_code'],
                            'warehouse_code' => $warehouseCode,
                            'quantity' => $item['quantity'],
                        ];
                    }
                }

                // Deduct stock
                if (!empty($stockItems) && ($payment['status'] ?? '') === 'paid') {
                    try {
                        $this->stockService->deductStock($stockItems);
                    } catch (\RuntimeException $e) {
                        Log::warning('Zooboxi stock deduction warning: ' . $e->getMessage(), [
                            'order_id' => $order->id,
                        ]);
                        // Don't fail the order — stock sync will correct it
                    }
                }

                return $order;
            });

            Log::info('Zooboxi order received', [
                'order_id' => $order->id,
                'woo_order_id' => $order->woo_order_id,
                'delivery_type' => $order->delivery_type,
                'warehouse' => $order->warehouse_code,
            ]);

            return response()->json([
                'status' => 'received',
                'order_id' => $order->id,
                'woo_order_id' => $order->woo_order_id,
                'warehouse_code' => $order->warehouse_code,
                'delivery_type' => $order->delivery_type,
            ], 201);

        } catch (\Exception $e) {
            Log::error('Zooboxi order creation failed', [
                'woo_order_id' => $request->woo_order_id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to process order: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * PUT /api/woo/orders/{woo_order_id}/status
     *
     * Update the delivery status of an existing order.
     */
    public function updateOrderStatus(Request $request, int $wooOrderId): JsonResponse
    {
        $request->validate([
            'delivery_status' => 'required|in:pending,preparing,ready_for_pickup,out_for_delivery,delivered,cancelled',
        ]);

        $order = ZooboxiOrder::where('woo_order_id', $wooOrderId)->firstOrFail();
        $oldStatus = $order->delivery_status;

        $order->update([
            'delivery_status' => $request->delivery_status,
        ]);

        // If cancelled and was paid, restore stock
        if ($request->delivery_status === 'cancelled' && $order->payment_status === 'paid') {
            $stockItems = $order->lines->map(fn($line) => [
                'item_code' => $line->item_code,
                'warehouse_code' => $line->warehouse_code,
                'quantity' => $line->quantity,
            ])->toArray();

            $this->stockService->restoreStock($stockItems);
        }

        return response()->json([
            'status' => 'updated',
            'woo_order_id' => $wooOrderId,
            'old_status' => $oldStatus,
            'new_status' => $request->delivery_status,
        ]);
    }

    // ─── Sync Status ────────────────────────────────────────────

    /**
     * GET /api/woo/sync-status
     *
     * Returns the latest sync status for each sync type.
     */
    public function getSyncStatus(): JsonResponse
    {
        $latestSyncs = ZooboxiSyncLog::latestByType();

        $status = [];
        foreach ($latestSyncs as $type => $log) {
            $status[$type] = $log ? [
                'status' => $log->status,
                'status_label' => $log->status_label,
                'records_synced' => $log->records_synced,
                'records_failed' => $log->records_failed,
                'started_at' => $log->started_at?->toIso8601String(),
                'completed_at' => $log->completed_at?->toIso8601String(),
                'duration_seconds' => $log->duration,
                'error_message' => $log->error_message,
            ] : null;
        }

        return response()->json([
            'sync_status' => $status,
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    // ─── Private Helpers ────────────────────────────────────────

    /**
     * Format a product for the API response.
     */
    private function formatProduct(Product $p): array
    {
        return [
            'item_code' => $p->item_code,
            'item_name' => $p->item_name,
            'foreign_name' => $p->foreign_name,
            'brand_code' => $p->items_group_code,
            'brand_name' => $p->brand?->name,
            'barcode' => $p->piece_barcode,
            'uom' => $p->inventory_uom,
            'sales_items_per_unit' => $p->sales_items_per_unit,
            'prices' => $p->prices ?? [],
            'image_url' => $p->image_url,
            'properties' => array_filter([
                'u_proprt1' => $p->u_proprt1,
                'u_proprt2' => $p->u_proprt2,
                'u_proprt3' => $p->u_proprt3,
                'u_proprt4' => $p->u_proprt4,
                'u_proprt5' => $p->u_proprt5,
            ]),
            'woo_product_id' => $p->woo_product_id,
            'woo_synced_at' => $p->woo_synced_at?->toIso8601String(),
            'updated_at' => $p->updated_at?->toIso8601String(),
        ];
    }
}
