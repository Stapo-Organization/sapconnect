<?php
// debug_stock.php

require __DIR__ . '/vendor/autoload.php';

$app = require __DIR__ . '/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\StockTransfer;
use Illuminate\Support\Facades\DB;

echo "--- DEBUG STOCK TRANSFERS ---\n";
echo "Default Connection: " . DB::getDefaultConnection() . "\n";
echo "Database Name: " . DB::connection()->getDatabaseName() . "\n";

$count = StockTransfer::count();
echo "Total Stock Transfers: " . $count . "\n";

if ($count > 0) {
    $first = StockTransfer::first();
    echo "First Record ID: " . $first->id . "\n";
    echo "Doc Num: " . $first->doc_num . "\n";
    echo "From: " . $first->from_warehouse . "\n";
    echo "To: " . $first->to_warehouse . "\n";
} else {
    echo "No records found in default connection.\n";
}

echo "--- CHECKING OTHER CONNECTIONS ---\n";
// Attempt to list other connections if possible from config? 
// For now just checking default.

echo "--- DEBUG END ---\n";
