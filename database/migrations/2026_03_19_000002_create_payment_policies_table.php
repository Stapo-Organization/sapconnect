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
        Schema::create('payment_policies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->constrained('suppliers')->cascadeOnDelete();
            $table->string('name');
            $table->timestamps();
        });

        Schema::create('payment_policy_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payment_policy_id')->constrained('payment_policies')->cascadeOnDelete();
            $table->decimal('percentage', 5, 2);
            $table->string('condition'); // e.g. 'on_shipment', 'on_clearance', 'invoice_date'
            $table->integer('due_days')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_policy_lines');
        Schema::dropIfExists('payment_policies');
    }
};
