<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Quality task OCCURRENCE — one per (task, warehouse, date, slot).
        Schema::create('quality_task_instances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quality_task_id')->constrained('quality_tasks')->cascadeOnDelete();
            $table->string('warehouse_code');
            $table->string('warehouse_name')->nullable();

            // Snapshot of the template at generation time (so later edits don't
            // corrupt history): {proof_type,min_photos,require_comment,checklist_items,priority,slot}
            $table->string('title');
            $table->text('description')->nullable();
            $table->json('requirements_snapshot');

            $table->string('status')->default('pending'); // pending | submitted | cancelled
            $table->date('scheduled_date');
            $table->string('slot_key')->default('_default'); // '_default' for slot-less tasks
            $table->string('priority')->default('medium');

            // Submission
            $table->text('comment')->nullable();
            $table->json('checklist_results')->nullable(); // {key:{checked,photo_ids}}
            $table->unsignedBigInteger('submitted_by')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('last_reminded_at')->nullable();
            $table->timestamps();

            $table->index('warehouse_code');
            $table->index('status');
            $table->index('scheduled_date');
            // Idempotent generation key.
            $table->unique(['quality_task_id', 'warehouse_code', 'scheduled_date', 'slot_key'], 'quality_instance_unique');

            $table->foreign('submitted_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quality_task_instances');
    }
};
