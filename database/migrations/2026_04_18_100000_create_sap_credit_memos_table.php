<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sap_credit_memos', function (Blueprint $table) {
            $table->id();
            $table->string('doc_num')->unique();
            $table->string('card_code')->index()->nullable();
            $table->date('doc_date')->nullable();
            $table->string('sales_employee_code')->nullable()->index();
            $table->decimal('doc_total', 15, 2)->default(0);
            $table->timestamps();
        });

        Schema::create('sap_credit_memo_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sap_credit_memo_id')->constrained('sap_credit_memos')->cascadeOnDelete();
            $table->string('item_code')->index();
            $table->string('warehouse_code')->nullable();
            $table->string('item_description')->nullable();
            $table->decimal('quantity', 15, 2)->default(0);
            $table->decimal('price', 15, 2)->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sap_credit_memo_lines');
        Schema::dropIfExists('sap_credit_memos');
    }
};
