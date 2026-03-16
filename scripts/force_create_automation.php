<?php

use App\Models\Automation;
use Illuminate\Support\Facades\Artisan;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$data = [
    'name' => 'Import Stock Transfers',
    'code' => 'sync_stock_transfers',
    'command_signature' => 'sap:sync-stock-transfers',
    'schedule_frequency' => 'everyMinute',
    'sap_database' => 'TEST_RETAIL01',
    'is_active' => true,
    'notify_sms' => true,
];

try {
    $automation = Automation::updateOrCreate(
        ['code' => $data['code']],
        $data
    );

    echo "SUCCESS: Automation '{$automation->name}' has been created/updated.\n";
    echo "  - ID: {$automation->id}\n";
    echo "  - DB: {$automation->sap_database}\n";
    echo "  - Schedule: {$automation->schedule_frequency}\n";
    echo "  - Active: " . ($automation->is_active ? 'Yes' : 'No') . "\n";
} catch (\Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}
