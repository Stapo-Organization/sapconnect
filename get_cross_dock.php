<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$storeCodes = \App\Models\Warehouse::where('warehouse_name', 'like', '%Store%')->pluck('warehouse_code')->toArray();

$transfer = \App\Models\SuggestedStockTransfer::with('product')
    ->whereIn('source_warehouse', $storeCodes)
    ->whereIn('target_warehouse', $storeCodes)
    ->first();

if ($transfer) {
    echo json_encode(['transfer' => $transfer->toArray(), 'source_name' => \App\Models\Warehouse::where('warehouse_code', $transfer->source_warehouse)->value('warehouse_name'), 'target_name' => \App\Models\Warehouse::where('warehouse_code', $transfer->target_warehouse)->value('warehouse_name')]);
} else {
    echo "NO_STORE_TRANSFER_FOUND";
}
echo "\n";
