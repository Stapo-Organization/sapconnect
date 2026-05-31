<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$sapClient = app(\App\Services\SAP\SapClient::class);
$sapClient->setCompanyDb('PPTC_V5_PROD');
$res = $sapClient->get('SalesPersons', ['$select' => 'SalesEmployeeCode,SalesEmployeeName']);
echo json_encode($res);
