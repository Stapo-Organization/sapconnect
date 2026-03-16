<?php

use App\Models\StockTransfer;
use App\Services\StockTransferService;
use App\Services\SAP\SapClient;
use Illuminate\Support\Facades\DB;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$output = "";
$output .= "--- Local Database Check ---\n";
$countTotal = StockTransfer::count();
$countProd = StockTransfer::where('sap_database', 'PPTC_V5_PROD')->count();
$countTest = StockTransfer::where('sap_database', 'TEST_RETAIL01')->count();

$output .= "Total StockTransfers: $countTotal\n";
$output .= " - PPTC_V5_PROD: $countProd\n";
$output .= " - TEST_RETAIL01: $countTest\n";

if ($countTotal == 0) {
    $output .= "\n[!] DB is empty. Automation failed to save or fetch data.\n";
} else {
    $output .= "\n[+] DB has data. If you can't see it in UI, it's a UI Filter issue.\n";
}

$output .= "\n--- SAP Connectivity Check (PPTC_V5_PROD) ---\n";

try {
    $client = app(SapClient::class);
    $client->setCompanyDb('PPTC_V5_PROD');

    $output .= "Querying InventoryTransferRequests (top 5)...\n";
    $response = $client->get('InventoryTransferRequests', ['$top' => 5]);

    if (isset($response['value'])) {
        $count = count($response['value']);
        $output .= "[+] SAP returned $count records in sample batch.\n";
        if ($count > 0) {
            $output .= "Sample DocNum: " . $response['value'][0]['DocNum'] . "\n";
        }
    } else {
        $output .= "[!] SAP returned no 'value' key. Response:\n";
        $output .= print_r($response, true);
    }

} catch (\Exception $e) {
    $output .= "[!] SAP Connection Failed: " . $e->getMessage() . "\n";
}

file_put_contents('debug_output.txt', $output);
echo "Debug output written to debug_output.txt\n";
