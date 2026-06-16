<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('warehouse_item_stocks', function (Blueprint $table) {
            // SAP per-warehouse committed (reserved) qty; in_stock & ordered already exist.
            $table->decimal('committed', 15, 4)->default(0)->after('in_stock');
        });
    }

    public function down(): void
    {
        Schema::table('warehouse_item_stocks', function (Blueprint $table) {
            $table->dropColumn('committed');
        });
    }
};
