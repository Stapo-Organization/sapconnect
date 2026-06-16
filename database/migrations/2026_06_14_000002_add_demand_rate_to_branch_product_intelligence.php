<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('branch_product_intelligence', function (Blueprint $table) {
            // Stockout-robust demand rate (units/day) used for trapped excess:
            // max(ADS90, ADS365, in-stock velocity) so an out-of-stock / no-sale
            // stretch can't deflate it into a fake "overstock".
            $table->decimal('demand_rate', 12, 4)->default(0)->after('velocity_blended');
        });
    }

    public function down(): void
    {
        Schema::table('branch_product_intelligence', function (Blueprint $table) {
            $table->dropColumn('demand_rate');
        });
    }
};
