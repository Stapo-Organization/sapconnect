<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * سجل إرسال التنبيهات عبر NotificationRouter (تدقيق).
 * يلتقط ما أُرسل فعلاً وعبر أي قناة، لكل حدث مرّ بالموجِّه
 * (تحويلات المخزون، تنبيهات SAP، التذكيرات، الإرسال اليدوي).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_dispatch_logs', function (Blueprint $table) {
            $table->id();
            $table->string('event_key');
            $table->string('channels')->nullable();            // 'email,push' المُستخدمة فعلاً
            $table->unsignedInteger('recipients_count')->default(0);
            $table->unsignedInteger('email_count')->default(0);
            $table->unsignedInteger('push_tokens_count')->default(0);
            $table->string('status')->default('success');       // success | partial | skipped | failed
            $table->text('title')->nullable();
            $table->text('error')->nullable();
            $table->timestamps();

            $table->index('event_key');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_dispatch_logs');
    }
};
