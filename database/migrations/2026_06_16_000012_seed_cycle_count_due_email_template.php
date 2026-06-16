<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * يبذر قالب بريد لحدث 'cycle_count_due' (تذكير الجرد الدوري) ليعمل البريد
 * إذا فعّل مدير المعرض قناة البريد له. المستلمون يُحلّون في الموجِّه من
 * مستخدمي المستودع، فلا حاجة لـ recipient_roles هنا.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (DB::table('email_notifications')->where('event_name', 'cycle_count_due')->exists()) {
            return;
        }

        DB::table('email_notifications')->insert([
            'event_name'      => 'cycle_count_due',
            'is_active'       => true,
            'subject_ar'      => 'تذكير: جرد دوري مستحق — {warehouse}',
            'subject_en'      => 'Reminder: cycle count due — {warehouse}',
            'body_ar'         => '<p>لديك مهمة جرد دوري مستحقة في فرع <strong>{warehouse}</strong> تشمل {items} صنفاً. يرجى البدء في أقرب وقت.</p>',
            'body_en'         => '<p>You have a cycle count due at <strong>{warehouse}</strong> covering {items} items. Please start at your earliest convenience.</p>',
            'recipient_roles' => json_encode([]),
            'cc_emails'       => json_encode([]),
            'created_at'      => now(),
            'updated_at'      => now(),
        ]);
    }

    public function down(): void
    {
        DB::table('email_notifications')->where('event_name', 'cycle_count_due')->delete();
    }
};
