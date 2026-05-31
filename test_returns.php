<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$sapClient = app(\App\Services\SAP\SapClient::class);
$sapClient->setCompanyDb('PPTC_V5_PROD');

try {
    $resReturns = $sapClient->get('Returns', ['$top' => 1, '$orderby' => 'DocEntry desc']);
    echo "Returns count: " . count($resReturns['value'] ?? []) . "\n";
    if (!empty($resReturns['value'])) {
         echo "Sample Return DocNum: " . $resReturns['value'][0]['DocNum'] . "\n";
    }
} catch (\Exception $e) {
    echo "Returns Error: " . $e->getMessage() . "\n";
}

try {
    $resCreditNotes = $sapClient->get('CreditNotes', ['$top' => 1, '$orderby' => 'DocEntry desc']);
    echo "CreditNotes count: " . count($resCreditNotes['value'] ?? []) . "\n";
    if (!empty($resCreditNotes['value'])) {
         echo "Sample CreditNote DocNum: " . $resCreditNotes['value'][0]['DocNum'] . "\n";
    }
} catch (\Exception $e) {
    echo "CreditNotes Error: " . $e->getMessage() . "\n";
}
