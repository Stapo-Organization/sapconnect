<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Full count: the moment the counted quantities refer to. When the showroom sells
 * again before the count is closed, any count entered after this moment gets the
 * net sales since then added back, so it still compares with the book at count time.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dateTime('sales_cutoff_at')->nullable()->after('recount_assignments');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn('sales_cutoff_at');
        });
    }
};
