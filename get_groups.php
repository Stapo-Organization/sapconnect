<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$sap = app(\App\Services\SAP\SapClient::class);
$sap->setCompanyDb('PPTC_V5_PROD');

$response = $sap->get('BusinessPartnerGroups', [
    '$filter' => "Type eq 'bbpgt_VendorGroup'"
]);

$groups = $response['value'] ?? [];
foreach($groups as $g) {
    echo $g['Code'] . ' | ' . $g['Name'] . "\n";
}
