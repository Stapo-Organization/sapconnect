<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('purchase_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->constrained('suppliers')->restrictOnDelete();
            $table->string('currency')->default('SAR');
            $table->foreignId('brand_id')->nullable()->constrained('brands')->nullOnDelete();
            $table->foreignId('payment_policy_id')->constrained('payment_policies')->restrictOnDelete();
            
            $table->string('pq_ref')->nullable();
            $table->decimal('pq_value', 15, 2)->nullable();
            
            $table->string('po_number')->nullable();
            $table->decimal('po_value', 15, 2)->nullable();
            
            $table->string('sync_status')->default('pending'); // pending, synced, failed
            
            $table->date('est_departure')->nullable();
            $table->string('factory_name')->nullable();
            $table->timestamps();
        });

        Schema::create('purchase_order_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('purchase_order_id')->constrained('purchase_orders')->cascadeOnDelete();
            $table->foreignId('product_id')->constrained('products')->restrictOnDelete();
            $table->string('description')->nullable();
            $table->integer('quantity')->default(1);
            $table->decimal('unit_price', 15, 2)->default(0);
            $table->decimal('total_price', 15, 2)->default(0);
            $table->integer('pallet_quantity')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('purchase_order_lines');
        Schema::dropIfExists('purchase_orders');
    }
};
