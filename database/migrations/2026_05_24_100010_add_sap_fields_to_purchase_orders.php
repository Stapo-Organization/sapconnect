<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('purchase_orders', function (Blueprint $table) {
            $table->unsignedBigInteger('sap_doc_entry')->nullable()->unique()->after('id');
            $table->string('sap_doc_num')->nullable()->after('sap_doc_entry');
            $table->date('doc_date')->nullable()->after('est_departure');
            $table->date('doc_due_date')->nullable()->after('doc_date');
            $table->string('doc_status')->nullable()->after('sync_status'); // Open, Closed, Cancelled
            $table->string('comments', 500)->nullable()->after('factory_name');

            // Make payment_policy_id nullable for SAP-synced POs
            $table->foreignId('payment_policy_id')->nullable()->change();
        });

        Schema::table('purchase_order_lines', function (Blueprint $table) {
            $table->unsignedInteger('sap_line_num')->nullable()->after('id');
            $table->string('item_code')->nullable()->after('sap_line_num');
            $table->string('item_description', 500)->nullable()->after('description');
            $table->string('warehouse_code')->nullable()->after('pallet_quantity');
            $table->string('uom')->nullable()->after('warehouse_code');

            // Make product_id nullable for SAP items not in our products table
            $table->foreignId('product_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('purchase_orders', function (Blueprint $table) {
            $table->dropColumn(['sap_doc_entry', 'sap_doc_num', 'doc_date', 'doc_due_date', 'doc_status', 'comments']);
        });

        Schema::table('purchase_order_lines', function (Blueprint $table) {
            $table->dropColumn(['sap_line_num', 'item_code', 'item_description', 'warehouse_code', 'uom']);
        });
    }
};
