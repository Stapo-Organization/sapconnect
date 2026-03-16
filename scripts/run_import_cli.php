<?php

use App\Services\StockTransferService;
use Illuminate\Support\Facades\Log;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Running StockTransfer Import (CLI Debug)...\n";

// 1. Setup Environment as PROD
$sap = new \App\Services\SAP\SapClient();
$sap->setCompanyDb('PPTC_V5_PROD');
$app->instance(\App\Services\SAP\SapClient::class, $sap);

// 2. Run Service
try {
    $service = app(StockTransferService::class); // Uses bound $sap
    // We expect the Service uses $this->sap (which is our bound instance? No, injected in constructor!)
    // If Service constructor is `public function __construct(SapClient $sap)`, it resolves from container.
    // So YES, it will use our configured instance.

    // We assume importFromSap uses $this->sap->getCompanyDb() to decide logic.

    echo "Starting Import...\n";
    $result = $service->importFromSap();

    print_r($result);

} catch (\Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString();
}

echo "\nDone.\n";
