<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$total = \App\Models\SuggestedStockTransfer::count();
$cross = \App\Models\SuggestedStockTransfer::whereHas('sourceWarehouse', function ($q) {
    $q->where('warehouse_name', 'like', '%Store%')
      ->orWhere('warehouse_name', 'like', '%store%')
      ->orWhere('warehouse_name', 'like', '%STORE%');
})->count();
$central = \App\Models\SuggestedStockTransfer::whereHas('sourceWarehouse', function ($q) {
    $q->where('warehouse_name', 'not like', '%Store%')
      ->where('warehouse_name', 'not like', '%ShipGo%')
      ->where('warehouse_name', 'not like', '%store%')
      ->where('warehouse_name', 'not like', '%STORE%');
})->count();

echo json_encode([
    'total' => $total,
    'cross' => $cross,
    'central' => $central
]);
echo "\n";
