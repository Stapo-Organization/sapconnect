<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Automation;

class CreditMemoFeatureSeeder extends Seeder
{
    public function run()
    {
        Automation::updateOrCreate(
            ['command_signature' => 'sap:sync-recent-credit-memos'],
            [
                'name' => 'Sync Recent Credit Memos',
                'code' => 'sync_recent_credit_memos',
                'schedule_frequency' => 'everyMinute',
                'is_active' => true,
            ]
        );
    }
}
