<?php

use App\Models\Automation;
use Illuminate\Support\Facades\Artisan;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$code = 'sync_stock_transfers_PPTC_V5_PROD';
$automation = Automation::where('code', $code)->first();

if ($automation) {
    echo "Found automation: {$automation->name}\n";
    $newSig = "sap:sync-stock-transfers --code={$code}";

    // FORCE UPDATE
    $automation->command_signature = $newSig;
    $automation->save();

    echo "Updated signature to: {$newSig}\n";

    // Verify Update
    $fresh = Automation::find($automation->id);
    echo "Verified DB Signature: {$fresh->command_signature}\n";

    // Run Once Immediately to Prove it works
    echo "Running command now...\n";
    $exitCode = Artisan::call('sap:sync-stock-transfers', ['--code' => $code]);
    echo "Exit Code: $exitCode\n";
    echo "Output: " . Artisan::output() . "\n";

} else {
    echo "Automation not found for code: $code\n";
}
