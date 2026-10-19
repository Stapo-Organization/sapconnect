<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * SAP's own inventory cost per item in the count's warehouse (OITW.AvgPrice,
 * Service Layer ItemWarehouseInfo.StandardAveragePrice), frozen with the book.
 * The accounting value of a variance is measured with it; unit_cost (the
 * product_costs estimate) stays as the fallback.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_counting_snapshots', function (Blueprint $table) {
            $table->decimal('sap_unit_cost', 15, 4)->nullable()->after('unit_cost');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_counting_snapshots', function (Blueprint $table) {
            $table->dropColumn('sap_unit_cost');
        });
    }
};
