<?php

use App\Models\Automation;
use Illuminate\Database\Migrations\Migration;

/**
 * Registers the daily Traqo auto-track in the dynamic automation scheduler.
 * Runs once daily; it self-limits via the monthly budget + per-run cap and the
 * permanent ledger, so a missed/extra run can never over-register.
 * Idempotent: firstOrCreate on the unique `code`.
 */
return new class extends Migration {
    public function up(): void
    {
        Automation::firstOrCreate(
            ['code' => 'traqo_auto_track'],
            [
                'name'               => 'تتبّع الحاويات (Traqo) — إضافة تلقائية للجديد',
                'command_signature'  => 'traqo:auto-track',
                'schedule_frequency' => 'daily',
                'is_active'          => true,
                'notify_sms'         => false,
            ]
        );
    }

    public function down(): void
    {
        Automation::where('code', 'traqo_auto_track')->delete();
    }
};
