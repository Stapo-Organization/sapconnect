<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * تفضيلات قنوات التنبيه لكل مستخدم.
 * كل سطر = اختيار صريح لقنوات حدث معيّن لهذا المستخدم:
 *   email / push (true/false). غياب السطر = استخدام افتراضي الكتالوج (config/notifications.php).
 * المفتاح event_key يطابق مفاتيح كتالوج التنبيهات.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('event_key'); // مثال: stock_transfer_created
            $table->boolean('email')->default(true);
            $table->boolean('push')->default(true);
            $table->timestamps();

            $table->unique(['user_id', 'event_key']);
            $table->index('event_key');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_preferences');
    }
};
