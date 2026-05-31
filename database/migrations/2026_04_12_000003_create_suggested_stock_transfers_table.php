<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('suggested_stock_transfers', function (Blueprint $table) {
            $table->id();
            $table->string('item_code');
            $table->string('source_warehouse');
            $table->string('target_warehouse');
            $table->decimal('suggested_quantity', 10, 2);
            $table->decimal('source_ads', 10, 2)->nullable();
            $table->decimal('source_stock', 10, 2)->nullable();
            $table->decimal('target_ads', 10, 2)->nullable();
            $table->decimal('target_stock', 10, 2)->nullable();
            $table->string('status')->default('pending'); // pending, approved, dismissed
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('suggested_stock_transfers');
    }
};
