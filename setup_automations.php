<?php

use App\Models\Automation;

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$automations = [
    [
        'sap_database' => 'PPTC_V5_PROD',
        'name' => 'Import Alrajhi Transactions (PPTC_V5_PROD)',
        'code' => 'sync_alrajhi_PPTC_V5_PROD',
        'command_signature' => 'sap:sync-alrajhi --code=sync_alrajhi_PPTC_V5_PROD',
        'schedule_frequency' => 'hourly',
        'is_active' => true,
        'notify_sms' => false,
    ],
    [
        'sap_database' => 'PPTC_V5_PROD',
        'name' => 'Import Brands (PPTC_V5_PROD)',
        'code' => 'sync_brands_PPTC_V5_PROD',
        'command_signature' => 'sap:sync-brands --code=sync_brands_PPTC_V5_PROD',
        'schedule_frequency' => 'hourly',
        'is_active' => true,
        'notify_sms' => false,
    ],
    [
        'sap_database' => 'PPTC_V5_PROD',
        'name' => 'Import Products (PPTC_V5_PROD)',
        'code' => 'sync_products_PPTC_V5_PROD',
        'command_signature' => 'sap:sync-products --code=sync_products_PPTC_V5_PROD',
        'schedule_frequency' => 'hourly',
        'is_active' => true,
        'notify_sms' => false,
    ],
    [
        'sap_database' => 'PPTC_V5_PROD',
        'name' => 'Import Warehouses (PPTC_V5_PROD)',
        'code' => 'sync_warehouses_PPTC_V5_PROD',
        'command_signature' => 'sap:sync-warehouses --code=sync_warehouses_PPTC_V5_PROD',
        'schedule_frequency' => 'hourly',
        'is_active' => true,
        'notify_sms' => false,
    ],
];

foreach ($automations as $data) {
    try {
        Automation::updateOrCreate(
            ['code' => $data['code']],
            $data
        );
        echo "Automation '{$data['name']}' created/updated successfully.\n";
    } catch (\Exception $e) {
        echo "Failed for '{$data['name']}': " . $e->getMessage() . "\n";
    }
}
echo "Done seeding automations!\n";
