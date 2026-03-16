<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('alrajhi_transactions', function (Blueprint $table) {
            $table->id();
            $table->string('msg_reference')->unique()->comment('Unique from NotifyCRDRHeader.MsgReference');
            $table->dateTime('creation_date')->nullable();
            $table->string('sap_card_code')->nullable();
            $table->string('transfer_customer_name')->nullable();
            $table->string('sap_customer_name')->nullable();
            $table->decimal('amount', 15, 2)->nullable();
            $table->string('customer_iban')->nullable();
            $table->string('payment_iban')->nullable();
            $table->json('invoices')->nullable();
            $table->string('status')->nullable();
            $table->json('raw_data')->nullable(); // Store full raw entry for debugging
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('alrajhi_transactions');
    }
};
