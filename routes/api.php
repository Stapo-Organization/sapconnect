<?php

use App\Http\Controllers\Api\UniversalSapController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// Auth Routes
Route::post('/login', [\App\Http\Controllers\Api\AuthController::class, 'login']);
Route::post('/verify-otp', [\App\Http\Controllers\Api\AuthController::class, 'verifyOtp']);

// Protected Mobile App Routes
Route::middleware(['auth:sanctum', 'set.sap.env'])->group(function () {
    // Auth Management
    Route::post('/logout', [\App\Http\Controllers\Api\AuthController::class, 'logout']);

    // Profile Management
    Route::get('/profile', [\App\Http\Controllers\Api\ProfileController::class, 'index']);
    Route::put('/profile', [\App\Http\Controllers\Api\ProfileController::class, 'update']);

    // Stock Transfers
    Route::get('/stock-transfers', [\App\Http\Controllers\Api\StockTransferController::class, 'index']);
    Route::get('/stock-transfers/{id}', [\App\Http\Controllers\Api\StockTransferController::class, 'show']);

    // Sender Actions
    Route::post('/stock-transfers/{id}/send-items', [\App\Http\Controllers\Api\StockTransferController::class, 'sendItems']);
    Route::post('/stock-transfers/{id}/confirm-send', [\App\Http\Controllers\Api\StockTransferController::class, 'confirmSend']);

    // Receiver Actions
    Route::post('/stock-transfers/{id}/receive-items', [\App\Http\Controllers\Api\StockTransferController::class, 'receiveItems']);
    Route::post('/stock-transfers/{id}/confirm-receive', [\App\Http\Controllers\Api\StockTransferController::class, 'confirmReceive']);

    // Audit Logs
    Route::get('/stock-transfers/{id}/logs', [\App\Http\Controllers\Api\StockTransferController::class, 'logs']);

    // FCM Token
    Route::put('/profile/fcm-token', [\App\Http\Controllers\Api\ProfileController::class, 'updateFcmToken']);
    Route::delete('/profile/fcm-token', [\App\Http\Controllers\Api\ProfileController::class, 'deleteFcmToken']);

    // Warehouses
    Route::get('/warehouses', function () {
        return response()->json([
            'data' => \App\Models\Warehouse::select('warehouse_code', 'warehouse_name', 'source')->get()
        ]);
    });

    // Legacy/Simple User Route
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    // Mobile Config
    Route::get('/mobile-settings', function () {
        return response()->json([
            'settings' => \App\Models\MobileAppSetting::all()->pluck('value', 'key'),
        ]);
    });

    // ─── Inventory Counting (Exhibition Manager) ───────────────
    Route::get('/inventory-countings', [\App\Http\Controllers\Api\InventoryCountingController::class, 'index']);
    Route::get('/inventory-countings/schedule', [\App\Http\Controllers\Api\InventoryCountingController::class, 'schedule']);
    Route::post('/inventory-countings', [\App\Http\Controllers\Api\InventoryCountingController::class, 'store']);
    Route::get('/inventory-countings/{id}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'show']);
    Route::post('/inventory-countings/{id}/scan', [\App\Http\Controllers\Api\InventoryCountingController::class, 'scan']);
    Route::post('/inventory-countings/{id}/lines', [\App\Http\Controllers\Api\InventoryCountingController::class, 'addLine']);
    Route::put('/inventory-countings/{id}/lines/{lineId}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'updateLine']);
    Route::delete('/inventory-countings/{id}/lines/{lineId}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'deleteLine']);
    Route::post('/inventory-countings/{id}/complete', [\App\Http\Controllers\Api\InventoryCountingController::class, 'complete']);
    Route::post('/inventory-countings/{id}/cancel', [\App\Http\Controllers\Api\InventoryCountingController::class, 'cancel']);

    // ─── Cycle Counting (Targets, Variance & Scheduling) ─────────
    Route::get('/inventory-countings/{id}/targets', [\App\Http\Controllers\Api\InventoryCountingController::class, 'targets']);
    Route::get('/inventory-countings/{id}/variance-report', [\App\Http\Controllers\Api\InventoryCountingController::class, 'varianceReport']);
    Route::post('/inventory-countings/{id}/lines/{lineId}/investigate', [\App\Http\Controllers\Api\InventoryCountingController::class, 'investigate']);
    Route::get('/inventory-countings/abc-summary/{warehouseCode}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'abcSummary']);
    Route::get('/inventory-countings/cycle-progress/{warehouseCode}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'cycleProgress']);

    // ─── Gamification ────────────────────────────────────────────
    Route::get('/gamification/me', [\App\Http\Controllers\Api\GamificationController::class, 'me']);
    Route::get('/gamification/badges', [\App\Http\Controllers\Api\GamificationController::class, 'badges']);
    Route::get('/gamification/leaderboard', [\App\Http\Controllers\Api\GamificationController::class, 'leaderboard']);

    // ─── Quality Control (Exhibition Manager) ────────────────────
    Route::get('/quality-tasks/summary', [\App\Http\Controllers\Api\QualityTaskController::class, 'summary']); // before {id}
    Route::get('/quality-tasks', [\App\Http\Controllers\Api\QualityTaskController::class, 'index']);
    Route::get('/quality-tasks/{id}', [\App\Http\Controllers\Api\QualityTaskController::class, 'show']);
    Route::post('/quality-tasks/{id}/photos', [\App\Http\Controllers\Api\QualityTaskController::class, 'uploadPhotos']);
    Route::delete('/quality-tasks/{id}/photos/{photoId}', [\App\Http\Controllers\Api\QualityTaskController::class, 'deletePhoto']);
    Route::post('/quality-tasks/{id}/submit', [\App\Http\Controllers\Api\QualityTaskController::class, 'submit']);

    // ─── Dashboard Stats (Exhibition Manager) ────────────────────
    Route::get('/dashboard-stats', function (Request $request) {
        $user = $request->user();
        $warehouseCodes = is_array($user->warehouse_code) ? $user->warehouse_code : (json_decode($user->warehouse_code, true) ?? []);

        // Transfers pending send (New status, user's from_warehouse)
        $pendingSend = \App\Models\StockTransfer::where('internal_status', 'New')
            ->whereIn('from_warehouse', $warehouseCodes)
            ->count();

        // Transfers pending receive (Shipped status, user's to_warehouse)
        $pendingReceive = \App\Models\StockTransfer::where('internal_status', 'Shipped')
            ->whereIn('to_warehouse', $warehouseCodes)
            ->count();

        // In-progress counting sessions (by this user or in their warehouses)
        $inProgressCounting = \App\Models\InventoryCounting::where('status', 'in_progress')
            ->where(function ($q) use ($user, $warehouseCodes) {
                $q->where('counted_by', $user->name)
                  ->orWhereIn('warehouse_code', $warehouseCodes);
            })
            ->count();

        return response()->json([
            'pending_send' => $pendingSend,
            'pending_receive' => $pendingReceive,
            'in_progress_counting' => $inProgressCounting,
        ]);
    });

    // Product lookup by barcode (for scanner)
    Route::get('/products/barcode/{barcode}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'lookupBarcode']);
});

// Store Public/Customer Routes
Route::prefix('store')->group(function () {
    Route::get('/brands', [\App\Http\Controllers\Api\StoreController::class, 'getBrands']);
    Route::get('/products', [\App\Http\Controllers\Api\StoreController::class, 'getProducts']);
    Route::get('/proxy-image', [\App\Http\Controllers\Api\StoreController::class, 'proxyImage']);
});

// SAP Integration Routes
// Protected by Custom App Token and LogSapRequests middleware
Route::middleware(['auth.app_token', 'set.sap.env', \App\Http\Middleware\LogSapRequests::class])->prefix('sap')->group(function () {

    // Generic Resource Handler
    // Matches /api/sap/Orders, /api/sap/BusinessPartners, etc.
    Route::get('/{resource}', [UniversalSapController::class, 'index']);
    Route::post('/{resource}', [UniversalSapController::class, 'store']);
    Route::patch('/{resource}/{id}', [UniversalSapController::class, 'update']);

    // Add specific custom controllers below if needed overriding the generic ones
    // Route::get('Inventory', [InventoryController::class, 'index']);
});

// ─── Zooboxi WooCommerce Integration ────────────────────────────
// Protected by WooCommerce API Token
Route::middleware([\App\Http\Middleware\AuthenticateWooToken::class])
    ->prefix('woo')
    ->group(function () {

    // Products
    Route::get('/products', [\App\Http\Controllers\Api\WooSyncController::class, 'getProducts']);
    Route::get('/products/{item_code}', [\App\Http\Controllers\Api\WooSyncController::class, 'getProduct']);

    // Stock
    Route::get('/stock', [\App\Http\Controllers\Api\WooSyncController::class, 'getStock']);
    Route::get('/stock/{warehouse_code}', [\App\Http\Controllers\Api\WooSyncController::class, 'getWarehouseStock']);

    // Prices
    Route::get('/prices', [\App\Http\Controllers\Api\WooSyncController::class, 'getPrices']);

    // Warehouses
    Route::get('/warehouses', [\App\Http\Controllers\Api\WooSyncController::class, 'getWarehouses']);

    // Delivery Options
    Route::post('/delivery-options', [\App\Http\Controllers\Api\WooSyncController::class, 'getDeliveryOptions']);

    // Orders
    Route::post('/orders', [\App\Http\Controllers\Api\WooSyncController::class, 'receiveOrder']);
    Route::put('/orders/{woo_order_id}/status', [\App\Http\Controllers\Api\WooSyncController::class, 'updateOrderStatus']);

    // Sync Status
    Route::get('/sync-status', [\App\Http\Controllers\Api\WooSyncController::class, 'getSyncStatus']);

    // TEMPORARY: Diagnostic endpoint to check stock data
    Route::get('/diagnostic/stock', function () {
        $sapWarehouses = \App\Models\Warehouse::where('source', 'production')
            ->get(['warehouse_code', 'warehouse_name']);
        
        $stockCounts = \App\Models\WarehouseItemStock::selectRaw('warehouse_code, COUNT(*) as cnt, SUM(in_stock) as total_stock')
            ->groupBy('warehouse_code')
            ->get();
        
        $zooboxiWarehouses = \App\Models\ZooboxiWarehouse::active()
            ->get(['warehouse_code', 'display_name_ar', 'city']);
        
        $totalStockRecords = \App\Models\WarehouseItemStock::count();
        $wooSyncProducts = \App\Models\Product::where('woo_sync', true)->count();
        
        return response()->json([
            'sap_warehouses' => $sapWarehouses,
            'stock_by_warehouse' => $stockCounts,
            'zooboxi_warehouses' => $zooboxiWarehouses,
            'total_stock_records' => $totalStockRecords,
            'woo_sync_product_count' => $wooSyncProducts,
        ]);
    });
});
