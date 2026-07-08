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

// Auth Routes (throttled — guards OTP send/verify against abuse & brute-force)
Route::post('/login', [\App\Http\Controllers\Api\AuthController::class, 'login'])
    ->middleware('throttle:10,1');
Route::post('/verify-otp', [\App\Http\Controllers\Api\AuthController::class, 'verifyOtp'])
    ->middleware('throttle:6,1');

// Protected Mobile App Routes
Route::middleware(['auth:sanctum', 'set.sap.env'])->group(function () {
    // Auth Management
    Route::post('/logout', [\App\Http\Controllers\Api\AuthController::class, 'logout']);

    // Profile Management
    Route::get('/profile', [\App\Http\Controllers\Api\ProfileController::class, 'index']);
    Route::put('/profile', [\App\Http\Controllers\Api\ProfileController::class, 'update']);

    // Stock Transfers — gated by app feature permissions (defense in depth)
    Route::middleware('feature:stock_transfer.view')->group(function () {
        Route::get('/stock-transfers', [\App\Http\Controllers\Api\StockTransferController::class, 'index']);
        Route::get('/stock-transfers/{id}', [\App\Http\Controllers\Api\StockTransferController::class, 'show']);
        Route::get('/stock-transfers/{id}/logs', [\App\Http\Controllers\Api\StockTransferController::class, 'logs']);
    });

    // Sender Actions — require the "send" ability
    Route::middleware('feature:stock_transfer.send')->group(function () {
        Route::post('/stock-transfers/{id}/send-items', [\App\Http\Controllers\Api\StockTransferController::class, 'sendItems']);
        Route::post('/stock-transfers/{id}/confirm-send', [\App\Http\Controllers\Api\StockTransferController::class, 'confirmSend']);
    });

    // Receiver Actions — require the "confirm_receive" ability
    Route::middleware('feature:stock_transfer.confirm_receive')->group(function () {
        Route::post('/stock-transfers/{id}/receive-items', [\App\Http\Controllers\Api\StockTransferController::class, 'receiveItems']);
        Route::post('/stock-transfers/{id}/confirm-receive', [\App\Http\Controllers\Api\StockTransferController::class, 'confirmReceive']);
    });

    // FCM Token
    Route::put('/profile/fcm-token', [\App\Http\Controllers\Api\ProfileController::class, 'updateFcmToken']);
    Route::delete('/profile/fcm-token', [\App\Http\Controllers\Api\ProfileController::class, 'deleteFcmToken']);

    // Notification channel preferences (email / app push) — per-user, audience-filtered
    Route::get('/profile/notification-preferences', [\App\Http\Controllers\Api\ProfileController::class, 'notificationPreferences']);
    Route::put('/profile/notification-preferences', [\App\Http\Controllers\Api\ProfileController::class, 'updateNotificationPreferences']);

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

    // ─── Super Admin: Quality Tasks management (إنشاء ومتابعة) ───────
    // Registered BEFORE /quality-tasks/{id} so the literal "manage" segment
    // isn't captured as an {id}.
    Route::middleware('feature:quality_admin.view')->group(function () {
        Route::get('/quality-tasks/manage', [\App\Http\Controllers\Api\QualityTaskAdminController::class, 'index']);
        Route::get('/quality-tasks/manage/instances', [\App\Http\Controllers\Api\QualityTaskAdminController::class, 'instances']); // before manage/{id}
        Route::get('/quality-tasks/manage/{id}', [\App\Http\Controllers\Api\QualityTaskAdminController::class, 'show'])->whereNumber('id');
    });
    Route::middleware('feature:quality_admin.manage')->group(function () {
        Route::post('/quality-tasks/manage', [\App\Http\Controllers\Api\QualityTaskAdminController::class, 'store']);
        Route::put('/quality-tasks/manage/{id}', [\App\Http\Controllers\Api\QualityTaskAdminController::class, 'update'])->whereNumber('id');
        Route::post('/quality-tasks/manage/{id}/generate', [\App\Http\Controllers\Api\QualityTaskAdminController::class, 'generate'])->whereNumber('id');
    });

    Route::get('/quality-tasks', [\App\Http\Controllers\Api\QualityTaskController::class, 'index']);
    Route::get('/quality-tasks/{id}', [\App\Http\Controllers\Api\QualityTaskController::class, 'show'])->whereNumber('id');
    Route::post('/quality-tasks/{id}/photos', [\App\Http\Controllers\Api\QualityTaskController::class, 'uploadPhotos']);
    Route::delete('/quality-tasks/{id}/photos/{photoId}', [\App\Http\Controllers\Api\QualityTaskController::class, 'deletePhoto']);
    Route::post('/quality-tasks/{id}/submit', [\App\Http\Controllers\Api\QualityTaskController::class, 'submit']);

    // ─── Zooboxi Express Orders (Exhibition Manager) ─────────────
    Route::get('/zooboxi-orders/summary', [\App\Http\Controllers\Api\ZooboxiOrderController::class, 'summary']); // before {id}
    Route::get('/zooboxi-orders', [\App\Http\Controllers\Api\ZooboxiOrderController::class, 'index']);
    Route::get('/zooboxi-orders/{id}', [\App\Http\Controllers\Api\ZooboxiOrderController::class, 'show']);
    Route::post('/zooboxi-orders/{id}/start', [\App\Http\Controllers\Api\ZooboxiOrderController::class, 'startPreparing']);
    Route::post('/zooboxi-orders/{id}/prepare', [\App\Http\Controllers\Api\ZooboxiOrderController::class, 'markPrepared']);

    // ─── Promotions / Ad Campaigns (Owner only — Super Admin) ────
    Route::get('/promotions/summary', [\App\Http\Controllers\Api\PromotionController::class, 'summary']); // before {id}
    Route::get('/promotions/placements', [\App\Http\Controllers\Api\PromotionController::class, 'placements']);
    Route::get('/promotions', [\App\Http\Controllers\Api\PromotionController::class, 'index']);
    Route::get('/promotions/{id}', [\App\Http\Controllers\Api\PromotionController::class, 'show']);
    Route::post('/promotions/{id}/approve', [\App\Http\Controllers\Api\PromotionController::class, 'approve']);
    Route::post('/promotions/{id}/publish', [\App\Http\Controllers\Api\PromotionController::class, 'publish']);
    Route::post('/promotions/{id}/reject', [\App\Http\Controllers\Api\PromotionController::class, 'reject']);
    Route::post('/promotions/{id}/regenerate', [\App\Http\Controllers\Api\PromotionController::class, 'regenerate']);
    Route::post('/promotions/{id}/refine', [\App\Http\Controllers\Api\PromotionController::class, 'refine']);

    // ─── Home Dashboard (Exhibition Manager) ─────────────────────
    // Single smart aggregation behind the home screen: ranked priority feed
    // + all module summaries in one round trip.
    Route::get('/home/overview', [\App\Http\Controllers\Api\HomeOverviewController::class, 'index']);

    // ─── Dashboard Stats (Exhibition Manager) ────────────────────
    // Kept for back-compat; shares the transfer/counting stat helper.
    Route::get('/dashboard-stats', [\App\Http\Controllers\Api\HomeOverviewController::class, 'dashboardStats']);

    // Product lookup by barcode (for scanner)
    Route::get('/products/barcode/{barcode}', [\App\Http\Controllers\Api\InventoryCountingController::class, 'lookupBarcode']);

    // ─── Product Search & Detail (Exhibition Manager) ────────────
    // Search by name / SAP code / barcode → product detail with stock across
    // every warehouse & showroom. Read-only; available to all app users.
    Route::get('/products/search', [\App\Http\Controllers\Api\ProductLookupController::class, 'search']);
    Route::get('/products/{itemCode}/detail', [\App\Http\Controllers\Api\ProductLookupController::class, 'detail']);

    // ─── Showroom Pulse / نبض المعرض (per-branch decision dashboard) ──
    Route::middleware('feature:showroom_pulse.view')->group(function () {
        Route::get('/showroom-pulse', [\App\Http\Controllers\Api\ShowroomPulseController::class, 'index']);
        Route::get('/showroom-pulse/lever', [\App\Http\Controllers\Api\ShowroomPulseController::class, 'leverItems']);
    });
    Route::middleware('feature:showroom_pulse.request_transfer')->group(function () {
        Route::post('/showroom-pulse/transfer-request', [\App\Http\Controllers\Api\ShowroomPulseController::class, 'requestTransfer']);
    });
    Route::middleware('feature:showroom_pulse.suggest_discount')->group(function () {
        Route::post('/showroom-pulse/discount-suggestion', [\App\Http\Controllers\Api\ShowroomPulseController::class, 'suggestDiscount']);
    });

    // ─── Super Admin: Retail Dashboard (لوحة البيع بالتجزئة) ─────────
    Route::middleware('feature:retail_dashboard.view')->group(function () {
        Route::get('/retail-dashboard', [\App\Http\Controllers\Api\RetailDashboardController::class, 'index']);
        Route::get('/retail-dashboard/branches/{warehouseCode}', [\App\Http\Controllers\Api\RetailDashboardController::class, 'branch']);
        Route::get('/retail-dashboard/branches/{warehouseCode}/items', [\App\Http\Controllers\Api\RetailDashboardController::class, 'branchItems']);
    });

    // ─── Super Admin: Smart Stock Distribution (التوزيع الذكي) ───────
    Route::middleware('feature:stock_distribution.view')->group(function () {
        Route::get('/stock-distribution', [\App\Http\Controllers\Api\StockDistributionController::class, 'index']);
        Route::get('/stock-distribution/status', [\App\Http\Controllers\Api\StockDistributionController::class, 'status']);
    });
    Route::middleware('feature:stock_distribution.run')->group(function () {
        Route::post('/stock-distribution/run', [\App\Http\Controllers\Api\StockDistributionController::class, 'run']);
    });

    // ─── Super Admin: Container Tracking (تتبّع الحاويات) ────────────
    Route::middleware('feature:container_tracking.view')->group(function () {
        Route::get('/container-tracking', [\App\Http\Controllers\Api\ContainerTrackingController::class, 'index']);
        Route::get('/container-tracking/{id}', [\App\Http\Controllers\Api\ContainerTrackingController::class, 'show'])->whereNumber('id');
    });

    // ─── Super Admin: Operations & Supply-Chain summary (read-only) ──
    Route::middleware('feature:supply_chain.view')->group(function () {
        Route::get('/supply-chain/overview', [\App\Http\Controllers\Api\SupplyChainSummaryController::class, 'overview']);
        Route::get('/supply-chain/po-summary', [\App\Http\Controllers\Api\SupplyChainSummaryController::class, 'poSummary']);
        Route::get('/supply-chain/arrived-shipments', [\App\Http\Controllers\Api\SupplyChainSummaryController::class, 'arrivedShipments']);
        Route::get('/supply-chain/registrations', [\App\Http\Controllers\Api\SupplyChainSummaryController::class, 'registrations']);
    });
});

// Store Public/Customer Routes
Route::prefix('store')->group(function () {
    Route::get('/brands', [\App\Http\Controllers\Api\StoreController::class, 'getBrands']);
    Route::get('/products', [\App\Http\Controllers\Api\StoreController::class, 'getProducts']);
    Route::get('/proxy-image', [\App\Http\Controllers\Api\StoreController::class, 'proxyImage']);

    // Pre-login landing feed for the Muntajat HUB app (company news + info).
    Route::get('/landing', [\App\Http\Controllers\Api\StoreController::class, 'getLanding']);
    Route::get('/news-image/{announcement}', [\App\Http\Controllers\Api\StoreController::class, 'newsImage']);
    // Per-brand intro page (logo + info + product gallery, no prices).
    Route::get('/brands/{code}', [\App\Http\Controllers\Api\StoreController::class, 'getBrand']);
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

    // Ad Campaigns (banners) — live campaigns + performance rollup
    Route::get('/campaigns/active', [\App\Http\Controllers\Api\CampaignDeliveryController::class, 'active']);
    Route::get('/campaigns/performance', [\App\Http\Controllers\Api\CampaignDeliveryController::class, 'performance']);

    // Brand boutique pages (/brand/<slug>/) — published brands + their AI banners
    Route::get('/brands', [\App\Http\Controllers\Api\BrandPageController::class, 'index']);
    Route::get('/brands/{code}/page', [\App\Http\Controllers\Api\BrandPageController::class, 'show']);

    // Sync Status
    Route::get('/sync-status', [\App\Http\Controllers\Api\WooSyncController::class, 'getSyncStatus']);

    // Zooboxi Intelligence (ranking snapshot, channel-safe clearance, FBT recs, event beacon)
    Route::get('/snapshot', [\App\Http\Controllers\Api\ZooboxiIntelligenceController::class, 'snapshot']);
    Route::get('/clearance', [\App\Http\Controllers\Api\ZooboxiIntelligenceController::class, 'clearance']);
    Route::get('/recommendations/{item_code}', [\App\Http\Controllers\Api\ZooboxiIntelligenceController::class, 'recommendations']);
    Route::post('/events', [\App\Http\Controllers\Api\ZooboxiIntelligenceController::class, 'storeEvent']);

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

// ─── ShipGo WMS Catalog Integration ──────────────────────────────
// Read-only catalog feed (SAP B1 mirror) for the ShipGo WMS. Bearer token.
Route::middleware([\App\Http\Middleware\AuthenticateShipGoToken::class])
    ->prefix('shipgo')
    ->group(function () {
        Route::get('/catalog', [\App\Http\Controllers\Api\ShipGoCatalogController::class, 'catalog']);
        Route::get('/stock', [\App\Http\Controllers\Api\ShipGoCatalogController::class, 'stock']);
    });
