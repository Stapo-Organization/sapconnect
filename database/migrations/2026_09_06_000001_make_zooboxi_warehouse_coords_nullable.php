<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A branch exists in SAP long before anyone surveys its GPS pin, and
     * sap:sync-warehouses now drafts a zooboxi row the moment a new store
     * appears. Those drafts are inactive and carry no coordinates yet, so the
     * columns can no longer be NOT NULL.
     *
     * Null is deliberate rather than 0/0: 0,0 is a real point in the Gulf of
     * Guinea and would silently produce a ~5000 km express radius check, while
     * null makes "not surveyed yet" unmistakable. The storefront already
     * follows this rule (config/b2b_showrooms.php: "a wrong pin on a map is
     * worse than no map").
     */
    public function up(): void
    {
        Schema::table('zooboxi_warehouses', function (Blueprint $table) {
            // Laravel 11's change() rewrites the whole definition, so the
            // original comments are restated rather than lost.
            $table->decimal('latitude', 10, 8)->nullable()
                ->comment('GPS latitude for distance calculation (null until surveyed)')
                ->change();
            $table->decimal('longitude', 11, 8)->nullable()
                ->comment('GPS longitude for distance calculation (null until surveyed)')
                ->change();
        });
    }

    public function down(): void
    {
        // Only reversible while no draft rows are still awaiting a survey.
        Schema::table('zooboxi_warehouses', function (Blueprint $table) {
            $table->decimal('latitude', 10, 8)->nullable(false)
                ->comment('GPS latitude for distance calculation')->change();
            $table->decimal('longitude', 11, 8)->nullable(false)
                ->comment('GPS longitude for distance calculation')->change();
        });
    }
};
