<?php

use App\Models\AutomationLog;
use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- AUTOMATION LOGS (Last 5) ---\n";
$logs = AutomationLog::latest()->take(5)->get();
foreach ($logs as $log) {
    echo "[$log->created_at] Status: {$log->status} | Msg: {$log->message}\n";
}

echo "\n--- RECORD COUNT ---\n";
echo "sap_stock_transfers: " . DB::table('sap_stock_transfers')->count() . "\n";
