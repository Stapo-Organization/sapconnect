<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Owner control to hide a specific brand from the Muntajat HUB app's public
 * brands showcase. SAP brand sync (SyncBrands) only upserts name/source, so
 * this column is preserved across re-syncs. Added to both brands + brands_test.
 */
return new class extends Migration
{
    public function up(): void
    {
        foreach (['brands', 'brands_test'] as $t) {
            if (Schema::hasTable($t) && !Schema::hasColumn($t, 'hidden_in_app')) {
                Schema::table($t, function (Blueprint $table) {
                    $table->boolean('hidden_in_app')->default(false);
                });
            }
        }
    }

    public function down(): void
    {
        foreach (['brands', 'brands_test'] as $t) {
            if (Schema::hasTable($t) && Schema::hasColumn($t, 'hidden_in_app')) {
                Schema::table($t, function (Blueprint $table) {
                    $table->dropColumn('hidden_in_app');
                });
            }
        }
    }
};
