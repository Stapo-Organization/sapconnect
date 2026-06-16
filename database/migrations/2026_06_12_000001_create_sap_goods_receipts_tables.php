<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * GRPO (Goods Receipt PO) mirror tables — imported FROM SAP into the sapconnect DB
 * by the sapconnect-layer command `sap:sync-goods-receipts`.
 *
 * Purpose: SAP `warehouse_item_stocks` is only a current snapshot (no history), so
 * we cannot tell a genuinely dead product from one that simply ran out of stock.
 * GRPO gives the real ARRIVAL events (item, qty, warehouse, date) AND the actual
 * purchase unit cost (`Price`), spanning 2+ years. Zooboxi intelligence reads these
 * tables (never SAP directly) to reconstruct in-stock periods, stockout-corrected
 * demand, and seed `product_costs`.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sap_goods_receipts', function (Blueprint $table) {
            $table->id();
            $table->string('sap_database')->default('PPTC_V5_PROD');
            $table->unsignedBigInteger('doc_entry');
            $table->string('doc_num')->nullable();
            $table->string('card_code')->nullable(); // vendor
            $table->date('doc_date')->nullable();
            $table->dateTime('update_date')->nullable();
            $table->timestamps();

            $table->unique(['sap_database', 'doc_entry']);
            $table->index('doc_date');
        });

        Schema::create('sap_goods_receipt_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sap_goods_receipt_id')->constrained()->cascadeOnDelete();
            $table->integer('line_num')->nullable();
            $table->string('item_code');
            $table->decimal('quantity', 15, 4)->default(0); // purchase-UoM quantity (SAP Quantity)
            $table->decimal('inventory_quantity', 15, 4)->default(0); // inventory-UoM quantity (SAP InventoryQuantity)
            $table->string('warehouse_code')->nullable();
            $table->decimal('unit_price', 15, 4)->default(0); // SAP GRPO line Price = actual purchase cost
            $table->decimal('line_total', 15, 4)->default(0);
            $table->date('doc_date')->nullable(); // denormalized for fast item×time queries
            $table->timestamps();

            $table->index(['item_code', 'doc_date']);
            $table->index(['warehouse_code', 'doc_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sap_goods_receipt_lines');
        Schema::dropIfExists('sap_goods_receipts');
    }
};
