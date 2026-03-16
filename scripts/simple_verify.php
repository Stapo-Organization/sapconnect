<?php

use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Checking Counts...\n";

$headers = DB::table('sap_stock_transfers_prod')->count();
$lines = DB::table('sap_stock_transfer_lines_prod')->count();

echo "Prod Headers: $headers\n";
echo "Prod Lines: $lines\n";
