<?php

use App\Models\Automation;
use Illuminate\Database\Migrations\Migration;

/**
 * Registers the daily Traqo shipment sync in the dynamic automation scheduler
 * (AutomationSchedule reads this table and wires $schedule->command(...)->daily()).
 * Idempotent: firstOrCreate on the unique `code`.
 */
return new class extends Migration {
    public function up(): void
    {
        Automation::firstOrCreate(
            ['code' => 'traqo_sync_shipments'],
            [
                'name'               => 'تتبّع الحاويات (Traqo) — مزامنة يومية',
                'command_signature'  => 'traqo:sync-shipments',
                'schedule_frequency' => 'daily',
                'is_active'          => true,
                'notify_sms'         => false,
            ]
        );
    }

    public function down(): void
    {
        Automation::where('code', 'traqo_sync_shipments')->delete();
    }
};
