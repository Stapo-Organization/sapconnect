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
        Schema::table('warehouse_item_stocks', function (Blueprint $table) {
            $table->decimal('ordered', 15, 4)->default(0)->after('in_stock');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('warehouse_item_stocks', function (Blueprint $table) {
            $table->dropColumn('ordered');
        });
    }
};
