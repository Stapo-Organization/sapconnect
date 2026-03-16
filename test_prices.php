<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$sap = app(\App\Services\SAP\SapClient::class);
$sap->setCompanyDb('TEST_RETAIL01');
$response = $sap->get('Items', [
    '$select' => 'ItemCode,ItemName,ItemPrices',
    '$top' => 100
]);

$foundPrice = false;
foreach($response['value'] as $item) {
    if(isset($item['ItemPrices'])) {
        foreach($item['ItemPrices'] as $price) {
             if($price['Price'] > 0) {
                 echo "Item: {$item['ItemCode']} - PriceList: {$price['PriceList']} - Price: {$price['Price']}\n";
                 $foundPrice = true;
             }
        }
    }
}
if(!$foundPrice) { echo "No prices greater than 0 found in the first 100 items.\n"; }
