<?php

use App\Models\ApiTransformer;
use App\Services\SAP\SapClient;
use Illuminate\Support\Facades\Log;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Debugging StockTransfer API View...\n";

$resource = 'StockTransfers';
$view = 'default';
$params = [
    '$filter' => "CreationDate gt '2025-12-01'",
    '$count' => 'true' // User used this
];

echo "1. Testing SAP Client connection and fetch...\n";
$sap = app(SapClient::class);
$databases = ['TEST_RETAIL01', 'PPTC_V5_PROD'];

foreach ($databases as $db) {
    echo "\n------------------------------------------------\n";
    echo "Checking Database: $db\n";

    // Force Change DB
    $sap->setCompanyDb($db);
    // Force Login to ensure we get a session for this DB
    // $sap->forceLogin(); // Not publicly exposed, but setCompanyDb triggers re-login on next request if session key changes

    try {
        $data = $sap->get($resource, $params);
        echo "SAP Response Keys: " . implode(', ', array_keys($data)) . "\n";

        if (isset($data['value'])) {
            $count = count($data['value']);
            echo "Record Count: " . $count . "\n";

            if ($count > 0) {
                // Check dates
                $first = $data['value'][0];
                echo "First Record Date: " . ($first['CreationDate'] ?? 'N/A') . "\n";
                echo "First Record Keys: " . implode(', ', array_keys($first)) . "\n";

                // Check for "StockTransferLines" or "DocumentLines"
                if (isset($first['StockTransferLines'])) {
                    echo "Found 'StockTransferLines': Yes. Count: " . count($first['StockTransferLines']) . "\n";
                    if (count($first['StockTransferLines']) > 0) {
                        echo "Line Keys: " . implode(', ', array_keys($first['StockTransferLines'][0])) . "\n";
                    }
                } elseif (isset($first['DocumentLines'])) {
                    echo "Found 'DocumentLines' (instead of StockTransferLines): Yes. Count: " . count($first['DocumentLines']) . "\n";
                } else {
                    echo "WARNING: No StockTransferLines or DocumentLines found!\n";
                }
            }
        } else {
            echo "No 'value' key.\n";
            if (isset($data['error'])) {
                print_r($data['error']);
            }
        }
    } catch (\Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
    }
}
exit; // Stop here for this test

echo "\n2. Testing Transformer...\n";
$transformer = ApiTransformer::findByResourceAndView($resource, $view);
if ($transformer) {
    echo "Transformer Found: Yes\n";
    echo "Mapping Count: " . count($transformer->mapping) . "\n";

    if (!empty($data['value'])) {
        echo "Transforming first item...\n";
        $item = $data['value'][0];
        $resourceClass = \App\Http\Resources\DynamicSapResource::class;
        $res = new $resourceClass($item, $transformer);
        $result = $res->toArray(request()); // Dummy request

        echo "Transformed Result Keys: " . implode(', ', array_keys($result)) . "\n";
        print_r($result);
    }
} else {
    echo "Transformer Found: NO (Check DB seeding)\n";
}
