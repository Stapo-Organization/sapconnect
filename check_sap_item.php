<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$sap = app(\App\Services\SAP\SapClient::class);
$sap->setCompanyDb('PPTC_V5_PROD');

$response = $sap->get('Items', [
    '$top' => 1,
    '$select' => 'ItemCode,Mainsupplier,ItemsGroupCode'
]);

dump($response['value'] ?? $response);
