<?php

use App\Models\Automation;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--------------------------------------------------\n";
echo "DEBUGGING AUTOMATIONS\n";
echo "--------------------------------------------------\n";

// 1. Check Database Connection
echo "Config DB Default: " . config('database.default') . "\n";
try {
    echo "Actual DB Name: " . DB::connection()->getDatabaseName() . "\n";
    echo "DB Host: " . config('database.connections.mysql.host') . "\n";
} catch (\Exception $e) {
    echo "DB Connection Error: " . $e->getMessage() . "\n";
}

// 2. Check Table
echo "Table 'automations' exists: " . (Schema::hasTable('automations') ? 'Yes' : 'No') . "\n";

// 3. Count Records
$count = Automation::count();
echo "Total Records: $count\n";

// 4. List Records
if ($count > 0) {
    foreach (Automation::all() as $auto) {
        echo " - [{$auto->id}] {$auto->name} (Code: {$auto->code}, Active: {$auto->is_active})\n";
    }
} else {
    echo "NO RECORDS FOUND. Attempting to create one now...\n";
    try {
        Automation::create([
            'name' => 'Debug Automation',
            'code' => 'debug_auto_' . time(),
            'command_signature' => 'debug:test',
            'schedule_frequency' => 'daily',
            'sap_database' => 'TEST_RETAIL01',
            'is_active' => 1
        ]);
        echo "Created 'Debug Automation'. Count is now: " . Automation::count() . "\n";
    } catch (\Exception $e) {
        echo "Failed to create: " . $e->getMessage() . "\n";
    }
}
echo "--------------------------------------------------\n";
