<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Multi-barcode table: every barcode an item answers to (SAP piece / carton /
 * other, barcodes scanned at the POS, manual). Filled by sap:sync-products and
 * products:import-barcode-aliases. products.piece_barcode remains the canonical
 * piece barcode used as the store SKU.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_barcodes', function (Blueprint $table) {
            $table->id();
            $table->string('item_code', 64)->index();
            $table->string('barcode', 64);
            $table->string('barcode_norm', 64)->index();   // digits only, leading zeros stripped
            $table->string('kind', 16)->default('piece');   // piece | carton | other | pos
            $table->string('source', 24)->default('sap');   // sap | pos_invoice | manual
            $table->integer('uom_entry')->nullable();
            $table->string('free_text', 100)->nullable();
            $table->boolean('is_primary')->default(false);
            $table->unsignedInteger('scan_count')->default(0);
            $table->timestamps();
            $table->unique(['item_code', 'barcode']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_barcodes');
    }
};
