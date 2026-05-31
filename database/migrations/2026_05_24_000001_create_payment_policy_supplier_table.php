<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Enables Many-to-Many relationship between Payment Policies and Suppliers.
     * Previously each policy was linked to a single supplier via supplier_id.
     */
    public function up(): void
    {
        Schema::create('payment_policy_supplier', function (Blueprint $table) {
            $table->id();
            $table->foreignId('payment_policy_id')->constrained()->cascadeOnDelete();
            $table->foreignId('supplier_id')->constrained()->cascadeOnDelete();
            $table->unique(['payment_policy_id', 'supplier_id']);
            $table->timestamps();
        });

        // Make supplier_id nullable in payment_policies since we now use pivot table
        Schema::table('payment_policies', function (Blueprint $table) {
            $table->foreignId('supplier_id')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_policy_supplier');

        Schema::table('payment_policies', function (Blueprint $table) {
            $table->foreignId('supplier_id')->nullable(false)->change();
        });
    }
};
