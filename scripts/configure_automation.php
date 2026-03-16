<?php

use App\Models\Automation;
use Illuminate\Support\Facades\Artisan;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

// 1. Configure "Stock Transfers" Automation
$code = 'sync_stock_transfers';
$automation = Automation::where('code', $code)->first();

if (!$automation) {
    echo "Automation '$code' not found. Creating...\n";
    $automation = Automation::create([
        'name' => 'Import Stock Transfers',
        'code' => $code,
        'command_signature' => 'sap:sync-stock-transfers',
    ]);
}

$automation->update([
    'schedule_frequency' => 'everyMinute',
    'sap_database' => 'TEST_RETAIL01',
    'is_active' => true,
    'notify_sms' => true,
]);

echo "Automation Configured:\n";
echo "  - Name: " . $automation->name . "\n";
echo "  - DB: " . $automation->sap_database . "\n";
echo "  - Schedule: " . $automation->schedule_frequency . "\n";
echo "  - Active: " . ($automation->is_active ? 'Yes' : 'No') . "\n";
echo "  - SMS: " . ($automation->notify_sms ? 'Yes' : 'No') . "\n";
echo "----------------------------------------\n";

// 2. Trigger Manually
echo "Triggering 'sap:sync-stock-transfers' now...\n";
try {
    $exitCode = Artisan::call('sap:sync-stock-transfers');
    echo Artisan::output();
    echo "Command Exit Code: $exitCode\n";
    if ($exitCode === 0) {
        echo "SUCCESS: Command executed.\n";
    } else {
        echo "FAILED: Command returned error.\n";
    }
} catch (\Exception $e) {
    echo "EXCEPTION: " . $e->getMessage() . "\n";
}
