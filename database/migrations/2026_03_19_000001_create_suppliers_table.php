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
        Schema::create('suppliers', function (Blueprint $table) {
            $table->id();
            
            // SAP Data (Synced, Read-only in UI)
            $table->string('sap_code')->unique();
            $table->string('name');
            $table->string('currency')->default('SAR');
            $table->decimal('credit_limit', 15, 2)->default(0);
            $table->decimal('open_po_value', 15, 2)->default(0);
            $table->decimal('achieved_amount', 15, 2)->default(0);
            
            // Classification & Admin Data (Manual Entry)
            $table->string('category')->nullable();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('email')->nullable();
            
            // Performance & Contracts (Manual Entry)
            $table->decimal('target_amount', 15, 2)->nullable();
            $table->string('contract_ref')->nullable();
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->text('renewal_conditions')->nullable();
            
            // Financial Agreements (Manual Entry)
            $table->decimal('agreed_discount', 5, 2)->nullable();
            $table->decimal('marketing_budget', 15, 2)->nullable();
            $table->decimal('rebates_bonuses', 15, 2)->nullable();
            $table->text('performance_notes')->nullable();
            
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('suppliers');
    }
};
