<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sap_invoices', function (Blueprint $table) {
            $table->id();
            $table->string('doc_num')->unique();
            $table->string('card_code')->nullable();
            $table->date('doc_date')->nullable();
            $table->string('sales_employee_code')->nullable();
            $table->decimal('doc_total', 15, 2)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sap_invoices');
    }
};
