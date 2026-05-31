<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->integer('expected_shipments_count')->default(1)->after('receiver_notes')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->dropColumn('expected_shipments_count');
        });
    }
};
