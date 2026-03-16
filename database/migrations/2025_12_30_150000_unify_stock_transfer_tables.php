<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // Drop old tables if they exist
        Schema::dropIfExists('sap_stock_transfer_lines_test');
        Schema::dropIfExists('sap_stock_transfers_test');
        Schema::dropIfExists('sap_stock_transfer_lines_prod');
        Schema::dropIfExists('sap_stock_transfers_prod');

        // Create unified table
        if (!Schema::hasTable('sap_stock_transfers')) {
            Schema::create('sap_stock_transfers', function (Blueprint $table) {
                $table->id();
                $table->string('sap_database')->index(); // Discriminator
                $table->integer('doc_entry');
                $table->integer('doc_num');
                $table->string('from_warehouse')->nullable();
                $table->string('to_warehouse')->nullable();
                $table->date('doc_date')->nullable();
                $table->string('document_status')->nullable();
                $table->string('internal_status')->nullable();
                $table->dateTime('creation_date')->nullable();
                $table->dateTime('update_date')->nullable();
                $table->timestamps();

                // Composite unique key
                $table->unique(['doc_entry', 'sap_database'], 'unique_transfer_db');
            });
        }

        if (!Schema::hasTable('sap_stock_transfer_lines')) {
            Schema::create('sap_stock_transfer_lines', function (Blueprint $table) {
                $table->id();
                $table->foreignId('stock_transfer_id')->constrained('sap_stock_transfers')->cascadeOnDelete();

                $table->string('item_code');
                $table->string('item_description')->nullable();
                $table->string('from_warehouse_code')->nullable();
                $table->string('warehouse_code')->nullable();
                $table->float('quantity')->default(0);
                $table->float('received_quantity')->default(0);

                $table->string('line_status')->nullable();

                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sap_stock_transfer_lines');
        Schema::dropIfExists('sap_stock_transfers');
    }
};
