<?php

use Illuminate\Support\Facades\Route;

Route::redirect('/developer/docs', '/docs/api');
Route::get('/', function () {
    return redirect('/admin');
});

Route::get('/clear-cache', function () {
    \Illuminate\Support\Facades\Artisan::call('optimize:clear');
    return 'Cache cleared successfully. Please go back to the dashboard.';
});

Route::get('/debug-role', function () {
    $email = request('email', 'm.mobarak@ppte.sa');
    $user = \App\Models\User::where('email', $email)->first();
    if (!$user) return 'User not found';
    return response()->json([
        'email' => $user->email,
        'roles' => $user->roles->pluck('name'),
        'has_super_admin' => $user->hasRole('Super Admin')
    ]);
});

Route::get('/sync-sap-products', function () {
    try {
        \Illuminate\Support\Facades\Artisan::call('sap:sync-products', ['--code' => 'sync_products_PPTC_V5_PROD']);
        return '<pre>' . \Illuminate\Support\Facades\Artisan::output() . '</pre>';
    } catch (\Exception $e) {
        return 'Error: ' . $e->getMessage();
    }
});

// ShipGo — customer account statement PDF (read-only from SAP). Filament auth guard.
Route::middleware(['web', 'auth'])
    ->get('/admin/shipgo/customers/{cardCode}/statement', \App\Http\Controllers\ShipGoStatementController::class)
    ->defaults('company', 'shipgo')
    ->name('shipgo.customers.statement');

// Muntajat (main company PPTC_V5_PROD) — same statement, read-only.
Route::middleware(['web', 'auth'])
    ->get('/admin/muntajat/customers/{cardCode}/statement', \App\Http\Controllers\ShipGoStatementController::class)
    ->defaults('company', 'muntajat')
    ->name('muntajat.customers.statement');

// Tax-invoice PDFs (ZATCA e-invoice rendered from SAP, read-only).
Route::middleware(['web', 'auth'])
    ->get('/admin/shipgo/invoices/{docEntry}/pdf', \App\Http\Controllers\InvoicePdfController::class)
    ->whereNumber('docEntry')
    ->defaults('company', 'shipgo')
    ->name('shipgo.invoices.pdf');
Route::middleware(['web', 'auth'])
    ->get('/admin/muntajat/invoices/{docEntry}/pdf', \App\Http\Controllers\InvoicePdfController::class)
    ->whereNumber('docEntry')
    ->defaults('company', 'muntajat')
    ->name('muntajat.invoices.pdf');

// Full count: signed, short-lived downloads minted by the API (shelf labels PDF, accountant CSV).
Route::get('/labels/{wh}', [\App\Http\Controllers\StoreLabelsController::class, 'labels'])
    ->middleware('signed:relative')->name('store-labels');
Route::get('/full-counts/{id}/export.csv', [\App\Http\Controllers\StoreLabelsController::class, 'export'])
    ->middleware('signed:relative')->whereNumber('id')->name('full-count-export');
