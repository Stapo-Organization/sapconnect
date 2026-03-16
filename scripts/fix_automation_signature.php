<?php

use App\Models\Automation;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$code = 'sync_stock_transfers_PPTC_V5_PROD';
$automation = Automation::where('code', $code)->first();

if ($automation) {
    echo "Found automation: {$automation->name}\n";
    $newSig = "sap:sync-stock-transfers --code={$code}";
    $automation->update(['command_signature' => $newSig]);
    echo "Updated signature to: {$newSig}\n";
} else {
    echo "Automation not found for code: $code\n";
    // List all to debug
    foreach (Automation::all() as $a) {
        echo " - {$a->code} ({$a->sap_database})\n";
    }
}
