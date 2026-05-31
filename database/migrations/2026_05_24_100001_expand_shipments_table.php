<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Expand shipments table with tracking fields from Excel
        Schema::table('shipments', function (Blueprint $table) {
            $table->date('received_date')->nullable()->after('eta')->comment('Actual received date at warehouse');
            $table->string('country_of_origin')->nullable()->after('origin_port')->comment('Country of origin (e.g. THAILAND)');
            $table->string('shipment_terms')->nullable()->after('transport_mode')->comment('FOB, CIF, FCA, EXW');
            $table->string('freight_invoice_no')->nullable()->after('total_freight_cost')->comment('Freight company invoice number');
            $table->decimal('freight_invoice_amount', 15, 2)->nullable()->after('freight_invoice_no')->comment('Freight invoice amount');
            $table->string('customs_manifest_no')->nullable()->after('freight_invoice_amount')->comment('Customs declaration number');
            $table->string('clearance_invoice_no')->nullable()->after('customs_manifest_no')->comment('Clearance broker invoice number');
            $table->decimal('clearance_amount', 15, 2)->nullable()->after('clearance_invoice_no')->comment('Clearance cost');
            $table->foreignId('broker_id')->nullable()->after('forwarder_id')->constrained('brokers')->nullOnDelete();
            $table->decimal('exchange_rate', 10, 4)->nullable()->after('clearance_amount')->comment('Exchange rate used for this shipment');
            $table->string('order_description')->nullable()->after('exchange_rate')->comment('Brief shipment description');
            $table->text('remarks')->nullable()->after('order_description');
            $table->text('notes')->nullable()->after('remarks');
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropForeign(['broker_id']);
            $table->dropColumn([
                'received_date', 'country_of_origin', 'shipment_terms',
                'freight_invoice_no', 'freight_invoice_amount',
                'customs_manifest_no', 'clearance_invoice_no', 'clearance_amount',
                'broker_id', 'exchange_rate', 'order_description', 'remarks', 'notes',
            ]);
        });
    }
};
