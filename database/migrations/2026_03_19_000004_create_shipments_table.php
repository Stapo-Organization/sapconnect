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
        Schema::create('shipments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('purchase_order_id')->constrained('purchase_orders')->cascadeOnDelete();
            
            $table->string('status')->default('scheduled'); // scheduled, shipped, arrived_port, delivered
            $table->boolean('is_announced')->default(false);
            
            $table->string('forwarder_name')->nullable();
            $table->string('transport_mode')->nullable(); // sea, air, land
            
            $table->string('origin_port')->nullable();
            
            // Assume warehouses table exists from current models (Warehouse.php)
            $table->foreignId('storage_location_id')->nullable()->constrained('warehouses')->nullOnDelete();
            
            $table->string('mbl')->nullable();
            $table->string('hbl')->nullable();
            
            $table->date('etd')->nullable();
            $table->date('eta')->nullable();
            
            $table->decimal('total_freight_cost', 15, 2)->default(0);
            
            $table->timestamps();
        });

        Schema::create('shipment_containers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            
            $table->string('container_type')->nullable(); // 20ft, 40ft
            $table->string('container_number')->nullable();
            $table->integer('pallet_count')->default(0);
            
            $table->decimal('freight_cost', 15, 2)->default(0);
            
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('shipment_containers');
        Schema::dropIfExists('shipments');
    }
};
