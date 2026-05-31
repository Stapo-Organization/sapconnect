<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sap_invoice_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sap_invoice_id')->constrained()->cascadeOnDelete();
            $table->string('item_code');
            $table->decimal('quantity', 15, 2)->default(0);
            $table->string('warehouse_code')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sap_invoice_lines');
    }
};
