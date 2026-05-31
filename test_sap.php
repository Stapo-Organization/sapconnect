<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $sapClient = app(\App\Services\SAP\SapClient::class);
    $sapClient->setCompanyDb('PPTC_V5_PROD');

    echo "Attempting to fetch 1 product...\n";
    $response = $sapClient->get('Items', [
        '$top' => 1,
        '$select' => 'ItemCode,ItemName,SalesItemsPerUnit,U_PortalSync,U_PROPRT1,U_PROPRT2,U_PROPRT3,U_PROPRT4,U_PROPRT5',
        '$orderby' => 'ItemCode DESC'
    ]);

    if (isset($response['value']) && count($response['value']) > 0) {
        $inv = $response['value'][0];
        echo "SUCCESS: Connection with SAP works.\n";
        print_r($inv);
    } else {
        echo "WARNING: Connection succeeded but no invoices found.\n";
        print_r($response);
    }
} catch (\Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
echo "\n";
