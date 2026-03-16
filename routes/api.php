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
