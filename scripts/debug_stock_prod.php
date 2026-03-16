<?php
// debug_stock_prod.php

require __DIR__ . '/vendor/autoload.php';

$app = require __DIR__ . '/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\StockTransferProd;

echo "--- DEBUG STOCK PROD ---\n";
try {
    $count = StockTransferProd::count();
    echo "StockTransferProd Count: " . $count . "\n";
} catch (\Exception $e) {
    echo "Error querying StockTransferProd: " . $e->getMessage() . "\n";
}
echo "--- DEBUG END ---\n";
