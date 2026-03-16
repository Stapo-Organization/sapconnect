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
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->string('item_code')->index();
            $table->string('item_name')->nullable();
            $table->string('foreign_name')->nullable();
            $table->integer('items_group_code')->nullable();
            $table->string('inventory_uom')->nullable();
            $table->string('piece_barcode')->nullable();
            $table->float('sales_items_per_unit')->nullable();
            $table->enum('source', ['test', 'production']);
            $table->timestamps();

            $table->unique(['item_code', 'source']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
