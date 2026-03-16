<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('automations', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('code')->unique(); // e.g., 'sync_brands'
            $table->string('command_signature'); // e.g., 'sap:sync-brands'
            $table->string('sap_database')->default('PPTC_V5_PROD');
            $table->string('schedule_frequency')->default('everyMinute'); // e.g., 'everyMinute', 'hourly', 'daily'
            $table->boolean('is_active')->default(false);
            $table->boolean('notify_sms')->default(false); // Toggle SMS notifications
            $table->timestamp('last_run_at')->nullable();
            $table->string('last_run_status')->nullable(); // 'success', 'failed'
            $table->timestamps();
        });

        Schema::create('automation_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('automation_id')->constrained('automations')->cascadeOnDelete();
            $table->string('status'); // 'success', 'failed', 'running'
            $table->text('message')->nullable();
            $table->integer('duration_seconds')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('automation_logs');
        Schema::dropIfExists('automations');
    }
};
