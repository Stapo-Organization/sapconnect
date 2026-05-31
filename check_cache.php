<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$employeeNames = \Illuminate\Support\Facades\Cache::remember('sap_sales_persons_map', 3600 * 24, function () {
    try {
        $sapClient = app(\App\Services\SAP\SapClient::class);
        $sapClient->setCompanyDb('PPTC_V5_PROD');
        $skip = 0;
        $map = [];
        while (true) {
            $res = $sapClient->get('SalesPersons', ['$select' => 'SalesEmployeeCode,SalesEmployeeName', '$skip' => $skip]);
            $values = $res['value'] ?? [];
            if (empty($values)) break;
            foreach ($values as $person) {
                $map[$person['SalesEmployeeCode']] = $person['SalesEmployeeName'];
            }
            if (!isset($res['odata.nextLink'])) break;
            $skip += count($values);
        }
        return $map;
    } catch (\Exception $e) {
        return ['error' => $e->getMessage()];
    }
});
echo "CACHED RES:\n";
print_r($employeeNames);
