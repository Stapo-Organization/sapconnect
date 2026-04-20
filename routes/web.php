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
