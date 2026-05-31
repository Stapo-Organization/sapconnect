<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add sap_warehouse_codes to map Zooboxi warehouses to SAP warehouse codes.
     * This allows a single Zooboxi warehouse (e.g. WH-RYD-01) to aggregate
     * stock from multiple SAP warehouses (e.g. ['01', '02']).
     */
    public function up(): void
    {
        Schema::table('zooboxi_warehouses', function (Blueprint $table) {
            $table->json('sap_warehouse_codes')->nullable()
                ->after('warehouse_code')
                ->comment('JSON array of SAP warehouse codes to aggregate stock from');
        });
    }

    public function down(): void
    {
        Schema::table('zooboxi_warehouses', function (Blueprint $table) {
            $table->dropColumn('sap_warehouse_codes');
        });
    }
};
