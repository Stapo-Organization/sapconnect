<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Automation;

class AutomationSeeder extends Seeder
{
    public function run()
    {
        $automations = [
            [
                'name' => 'Import Brands',
                'code' => 'sync_brands',
                'command_signature' => 'sap:sync-brands',
                'schedule_frequency' => 'everyMinute',
                'notify_sms' => false,
            ],
            [
                'name' => 'Import Products',
                'code' => 'sync_products',
                'command_signature' => 'sap:sync-products',
                'schedule_frequency' => 'everyMinute',
                'notify_sms' => false,
            ],
            [
                'name' => 'Import Warehouses',
                'code' => 'sync_warehouses',
                'command_signature' => 'sap:sync-warehouses',
                'schedule_frequency' => 'daily', // Defaults to less frequent
                'notify_sms' => false,
            ],
            [
                'name' => 'Import Stock Transfers',
                'code' => 'sync_stock_transfers',
                'command_signature' => 'sap:sync-stock-transfers',
                'schedule_frequency' => 'everyMinute',
                'notify_sms' => true, // Enabled by default as per recent work
            ],
        ];

        foreach ($automations as $auto) {
            Automation::firstOrCreate(
                ['code' => $auto['code']],
                $auto
            );
        }
    }
}
