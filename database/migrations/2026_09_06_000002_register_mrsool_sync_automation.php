<?php

use App\Models\Automation;
use Illuminate\Database\Migrations\Migration;

/**
 * Registers the Mrsool active-delivery poller in the dynamic automation
 * scheduler. Runs every minute but exits immediately when the integration is
 * disabled or there is no non-terminal delivery — so it costs nothing at rest
 * and only polls while a courier is actually out.
 * Idempotent: firstOrCreate on the unique `code`.
 */
return new class extends Migration
{
    public function up(): void
    {
        Automation::firstOrCreate(
            ['code' => 'mrsool_sync_active'],
            [
                'name'               => 'مرسول — تحديث التوصيلات النشطة',
                'command_signature'  => 'mrsool:sync-active',
                'schedule_frequency' => 'everyMinute',
                'is_active'          => true,
                'notify_sms'         => false,
            ]
        );
    }

    public function down(): void
    {
        Automation::where('code', 'mrsool_sync_active')->delete();
    }
};
