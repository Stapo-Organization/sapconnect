<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\Automation;
use Illuminate\Support\Facades\Artisan;

echo "--- Managing Automations ---\n";

$old = Automation::where('code', 'sync_stock_transfers')->first();
if ($old) {
    $old->delete();
    echo "DELETED legacy automation 'sync_stock_transfers'.\n";
} else {
    echo "Legacy automation 'sync_stock_transfers' NOT FOUND.\n";
}

$new = Automation::where('code', 'sync_stock_transfers_PPTC_V5_PROD')->first();
if ($new) {
    echo "FOUND new automation: " . $new->name . "\n";
    if (!$new->is_active) {
        $new->update(['is_active' => true]);
        echo "ACTIVATED new automation.\n";
    }
} else {
    echo "New automation 'sync_stock_transfers_PPTC_V5_PROD' NOT FOUND! Creating it.\n";
    $new = Automation::create([
        'code' => 'sync_stock_transfers_PPTC_V5_PROD',
        'name' => 'Import Stock Transfers (PPTC_V5_PROD)',
        'sap_database' => 'PPTC_V5_PROD',
        'command_signature' => 'sap:sync-stock-transfers --code=sync_stock_transfers_PPTC_V5_PROD',
        'schedule_frequency' => 'daily',
        'is_active' => true,
        'notify_sms' => true
    ]);
}

echo "\n--- Running the Automation Command ---\n";
try {
    Artisan::call('sap:sync-stock-transfers', ['--code' => 'sync_stock_transfers_PPTC_V5_PROD']);
    echo Artisan::output();
} catch (\Exception $e) {
    echo "Error running command: " . $e->getMessage() . "\n";
}

echo "--- Finished ---\n";
