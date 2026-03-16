<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Models\StockTransfer;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Current StockTransfers: " . StockTransfer::count() . "\n";

DB::statement('SET FOREIGN_KEY_CHECKS=0;');
DB::table('sap_stock_transfer_lines')->truncate();
DB::table('sap_stock_transfers')->truncate();
DB::statement('SET FOREIGN_KEY_CHECKS=1;');

echo "After Truncate: " . StockTransfer::count() . "\n";
echo "Done.\n";
