<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $sap = app(\App\Services\SAP\SapClient::class);
    $sap->setCompanyDb('PPTC_V5_PROD');

    $response = $sap->get('Items', [
        '$select' => 'ItemCode,ItemName,SalesItemsPerUnit,U_PortalSync,U_PROPRT1,U_PROPRT2,U_PROPRT3,U_PROPRT4,U_PROPRT5',
        '$top' => 1
    ]);

    if (isset($response['value']) && count($response['value']) > 0) {
        echo "Found item: \n";
        print_r($response['value'][0]);
    } else {
        echo "No items found or API error.\n";
        if (isset($response['error'])) {
            print_r($response['error']);
        }
    }
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
