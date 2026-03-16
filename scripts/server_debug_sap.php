<?php

use App\Models\StockTransfer;
use App\Services\StockTransferService;
use App\Services\SAP\SapClient;
use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- Local Database Check ---\n";
$countTotal = StockTransfer::count();
$countProd = StockTransfer::where('sap_database', 'PPTC_V5_PROD')->count();
$countTest = StockTransfer::where('sap_database', 'TEST_RETAIL01')->count();

echo "Total StockTransfers: $countTotal\n";
echo " - PPTC_V5_PROD: $countProd\n";
echo " - TEST_RETAIL01: $countTest\n";

if ($countTotal == 0) {
    echo "\n[!] DB is empty. Automation failed to save or fetch data.\n";
} else {
    echo "\n[+] DB has data. If you can't see it in UI, it's a UI Filter issue.\n";
}

echo "\n--- SAP Connectivity Check (PPTC_V5_PROD) ---\n";

try {
    $client = app(SapClient::class);
    $client->setCompanyDb('PPTC_V5_PROD');

    echo "Querying InventoryTransferRequests (top 5)...\n";
    $response = $client->get('InventoryTransferRequests', ['$top' => 5]);

    if (isset($response['value'])) {
        $count = count($response['value']);
        echo "[+] SAP returned $count records in sample batch.\n";
        if ($count > 0) {
            echo "Sample DocNum: " . $response['value'][0]['DocNum'] . "\n";
        }
    } else {
        echo "[!] SAP returned no 'value' key. Response:\n";
        print_r($response);
    }

} catch (\Exception $e) {
    echo "[!] SAP Connection Failed: " . $e->getMessage() . "\n";
}
