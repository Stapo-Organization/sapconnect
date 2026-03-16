<?php

use Illuminate\Support\Facades\Schema;
use App\Models\StockTransfer;
use App\Services\StockTransferService;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Verifying Stock Transfer Setup...\n";

// 1. Check Tables
$tables = [
    'sap_stock_transfers_test',
    'sap_stock_transfers_prod',
    'sap_stock_transfer_lines_test',
    'sap_stock_transfer_lines_prod'
];

$missing = [];
foreach ($tables as $table) {
    if (Schema::hasTable($table)) {
        echo "[OK] Table '$table' exists.\n";
    } else {
        echo "[FAIL] Table '$table' missing.\n";
        $missing[] = $table;
    }
}

// 2. Check Service
try {
    $service = app(StockTransferService::class);
    echo "[OK] StockTransferService instantiated successfully.\n";
} catch (\Exception $e) {
    echo "[FAIL] StockTransferService instantiation failed: " . $e->getMessage() . "\n";
}

// 3. Check User Column
if (Schema::hasColumn('users', 'warehouse_code')) {
    echo "[OK] Column 'warehouse_code' exists in 'users' table.\n";
} else {
    echo "[FAIL] Column 'warehouse_code' missing in 'users' table.\n";
    $missing[] = 'users.warehouse_code';
}

if (!empty($missing)) {
    echo "\nSummary: Setup INCOMPLETE. Please run migrations.\n";
    echo "Command: php artisan migrate\n";
    exit(1);
} else {
    echo "\nSummary: Setup COMPLETE.\n";
    exit(0);
}
