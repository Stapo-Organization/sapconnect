<?php

use App\Models\Automation;
use Illuminate\Database\Migrations\Migration;

/**
 * Registers the daily push of Traqo ETD/ETA into the Google Sheet ledger.
 * Idempotent firstOrCreate on the unique `code`.
 */
return new class extends Migration {
    public function up(): void
    {
        Automation::firstOrCreate(
            ['code' => 'traqo_push_sheet'],
            [
                'name'               => 'تتبّع الحاويات (Traqo) → Google Sheet — يومي',
                'command_signature'  => 'traqo:push-sheet',
                'schedule_frequency' => 'daily',
                'is_active'          => true,
                'notify_sms'         => false,
            ]
        );
    }

    public function down(): void
    {
        Automation::where('code', 'traqo_push_sheet')->delete();
    }
};
