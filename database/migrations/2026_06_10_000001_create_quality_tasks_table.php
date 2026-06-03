<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Quality task TEMPLATE — one row per warehouse (fan-out on create).
        Schema::create('quality_tasks', function (Blueprint $table) {
            $table->id();
            $table->string('warehouse_code');
            $table->string('title');
            $table->text('description')->nullable();

            // Dynamic proof requirements
            $table->string('proof_type')->default('photo'); // acknowledge | photo | checklist
            $table->unsignedSmallInteger('min_photos')->default(1); // for proof_type=photo
            $table->boolean('require_comment')->default(false);
            $table->json('checklist_items')->nullable(); // [{key,label,require_photo}]

            // Schedule
            $table->string('recurrence')->default('daily'); // once | daily | weekly
            $table->json('days_of_week')->nullable(); // [0..6] Carbon dayOfWeek (0=Sun), for weekly
            $table->json('slots')->nullable(); // [{key,label_ar,label_en}] e.g. morning/afternoon
            $table->string('priority')->default('medium'); // high | medium | low
            $table->boolean('is_active')->default(true);
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();

            $table->string('assignment')->default('branch_manager');
            $table->timestamp('last_generated_at')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamps();

            $table->index('warehouse_code');
            $table->index(['is_active', 'warehouse_code']);
            $table->index(['is_active', 'recurrence']);

            $table->foreign('warehouse_code')->references('warehouse_code')->on('warehouses');
            $table->foreign('created_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quality_tasks');
    }
};
