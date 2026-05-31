<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$transfers = \App\Models\SuggestedStockTransfer::with('product')->where('status', 'pending')->get();

$totalTransfers = $transfers->count();
$totalItems = $transfers->pluck('item_code')->unique()->count();
$totalQuantity = $transfers->sum('suggested_quantity');

// Group by Source Type (Store vs Warehouse)
$mainWarehouses = ['AGL001', '3PL001', 'WAF001', 'WAP001', 'WBF001'];
$fromWarehouseToStore = 0;
$fromStoreToStore = 0;

$sourceCounts = [];
$productQty = [];
$productOps = [];

foreach ($transfers as $t) {
    if (in_array($t->source_warehouse, $mainWarehouses)) {
        $fromWarehouseToStore++;
    } else {
        $fromStoreToStore++;
    }

    if (!isset($sourceCounts[$t->source_warehouse])) {
        $sourceCounts[$t->source_warehouse] = 0;
    }
    $sourceCounts[$t->source_warehouse] += intval($t->suggested_quantity);

    // Product calculations
    $productName = $t->product ? $t->product->item_code : $t->item_code;
    
    if (!isset($productQty[$productName])) {
        $productQty[$productName] = 0;
        $productOps[$productName] = 0;
    }
    $productQty[$productName] += intval($t->suggested_quantity);
    $productOps[$productName]++;
}

arsort($sourceCounts);
$topSources = array_slice($sourceCounts, 0, 5, true);

arsort($productQty);
$topProductsQty = array_slice($productQty, 0, 5, true);

arsort($productOps);
$topProductsOps = array_slice($productOps, 0, 5, true);

echo json_encode([
    'total_transfers' => $totalTransfers,
    'warehouse_to_store' => $fromWarehouseToStore,
    'store_to_store' => $fromStoreToStore,
    'top_sources' => $topSources,
    'top_products_qty' => $topProductsQty,
    'top_products_ops' => $topProductsOps
]);
echo "\n";
