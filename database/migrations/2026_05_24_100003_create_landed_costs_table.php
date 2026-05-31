<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('landed_costs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('purchase_order_id')->constrained()->cascadeOnDelete();
            $table->decimal('exchange_rate', 10, 4)->comment('Currency to SAR rate');
            $table->decimal('vat_percentage', 5, 2)->default(15.00);
            $table->decimal('shipping_cost_foreign', 15, 2)->default(0)->comment('Total shipping in supplier currency');
            $table->decimal('shipping_cost_sar', 15, 2)->default(0)->comment('Total shipping in SAR');
            $table->decimal('customs_cost', 15, 2)->default(0)->comment('Customs declaration cost');
            $table->decimal('broker_cost', 15, 2)->default(0)->comment('Clearance broker cost');
            $table->decimal('total_additional_costs', 15, 2)->default(0)->comment('Sum of all additional costs (auto)');
            $table->string('preparation_status')->default('draft')->comment('draft, ready');
            $table->string('pricing_status')->default('pending')->comment('pending, ready');
            $table->text('remarks')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('landed_costs');
    }
};
