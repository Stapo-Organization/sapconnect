<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_countings', function (Blueprint $table) {
            $table->id();
            $table->string('warehouse_code');
            $table->string('warehouse_name')->nullable();
            $table->enum('status', ['draft', 'completed'])->default('draft');
            $table->foreignId('counted_by')->constrained('users')->cascadeOnDelete();
            $table->text('notes')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index('warehouse_code');
            $table->index('status');
        });

        Schema::create('inventory_counting_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('inventory_counting_id')->constrained('inventory_countings')->cascadeOnDelete();
            $table->string('item_code');
            $table->string('item_name')->nullable();
            $table->string('piece_barcode')->nullable();
            $table->decimal('counted_quantity', 15, 4)->default(0);
            $table->timestamps();

            $table->index('item_code');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_counting_lines');
        Schema::dropIfExists('inventory_countings');
    }
};
