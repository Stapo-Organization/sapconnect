<?php

use App\Models\Automation;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- Automation Records ---\n";
foreach (Automation::all() as $a) {
    echo "ID: {$a->id} | Code: {$a->code} | Active: {$a->is_active} | Freq: {$a->schedule_frequency} | Sig: '{$a->command_signature}'\n";
}

echo "\n--- Schedule List ---\n";
Artisan::call('schedule:list');
echo Artisan::output();

echo "\n--- Test Run of Command ---\n";
$code = 'sync_stock_transfers_PPTC_V5_PROD';
$cmd = "sap:sync-stock-transfers --code={$code}";
echo "Executing: php artisan $cmd\n";

// We execute via shell to see real output
passthru("php artisan $cmd");

echo "\n--- Done ---\n";
