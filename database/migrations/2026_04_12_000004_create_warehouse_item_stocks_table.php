<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('warehouse_item_stocks', function (Blueprint $table) {
            $table->id();
            $table->string('item_code');
            $table->string('warehouse_code');
            $table->decimal('in_stock', 15, 4)->default(0);
            $table->timestamps();

            $table->unique(['item_code', 'warehouse_code']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warehouse_item_stocks');
    }
};
