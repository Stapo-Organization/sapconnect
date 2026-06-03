<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_cycle_plans', function (Blueprint $table) {
            $table->id();
            $table->string('warehouse_code');
            $table->string('plan_name');
            $table->integer('cycle_length_weeks')->default(13); // Quarter = 13 weeks
            $table->string('counting_day')->default('sunday'); // Day of the week for counting
            $table->integer('weekly_cap')->default(120); // Max items per weekly session
            $table->integer('a_frequency')->default(2); // Times A items counted per cycle
            $table->integer('b_frequency')->default(1); // Times B items counted per cycle
            $table->integer('c_frequency')->default(1); // Times C items counted per cycle
            $table->decimal('tolerance_a', 5, 2)->default(2.00); // Tolerance % for A items
            $table->decimal('tolerance_b', 5, 2)->default(5.00);
            $table->decimal('tolerance_c', 5, 2)->default(10.00);
            $table->boolean('is_active')->default(true);
            $table->date('current_cycle_start')->nullable(); // Start of current cycle
            $table->integer('current_week_number')->default(0); // Week # in current cycle
            $table->timestamp('last_generated_at')->nullable();
            $table->date('next_due_date')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->timestamps();

            $table->foreign('warehouse_code')->references('warehouse_code')->on('warehouses');
            $table->foreign('created_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_cycle_plans');
    }
};
