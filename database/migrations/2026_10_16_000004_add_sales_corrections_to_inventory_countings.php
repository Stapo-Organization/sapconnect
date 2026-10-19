<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Full count: cashier swaps reported by the branch after the sales cut-off —
 * [{from, to, qty, at, note}]: the till recorded `from` but the customer took `to`.
 * The sales tracking moves those pieces from one item to the other.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->json('sales_corrections')->nullable()->after('sales_cutoff_at');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn('sales_corrections');
        });
    }
};
