<?php

use App\Models\StockTransfer;
use App\Models\User;
use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- DB RECORD COUNTS ---\n";
try {
    $count = DB::table('sap_stock_transfers')->count();
    echo "Total Rows in 'sap_stock_transfers': $count\n";

    $grouped = DB::table('sap_stock_transfers')
        ->select('sap_database', DB::raw('count(*) as total'))
        ->groupBy('sap_database')
        ->get();

    foreach ($grouped as $g) {
        echo " - Database [{$g->sap_database}]: {$g->total}\n";
    }
} catch (\Exception $e) {
    echo "Error counting DB: " . $e->getMessage() . "\n";
}

echo "\n--- USER SETTINGS (ID 1) ---\n";
$user = User::find(1);
if ($user) {
    echo "User: {$user->name} (ID: 1)\n";
    echo "Warehouse Code: " . ($user->warehouse_code ?: "NULL (Visible to All)") . "\n";
} else {
    echo "User ID 1 not found.\n";
}

echo "\n--- CHECKING RESOURCE QUERY SCOPE LOGIC ---\n";
// Simulate the resource query modification
if ($user && $user->warehouse_code) {
    echo "User has warehouse code '{$user->warehouse_code}'.\n";
    $visibleCount = StockTransfer::where(function ($q) use ($user) {
        $q->where('from_warehouse', $user->warehouse_code)
            ->orWhere('to_warehouse', $user->warehouse_code);
    })->count();
    echo "Records visible to this user: $visibleCount\n";
} else {
    echo "User has NO warehouse code. Should see ALL records.\n";
}
