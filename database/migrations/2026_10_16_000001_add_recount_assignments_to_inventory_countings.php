<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Full count: the supervisor hands out the blind recount — item_code => user_id.
 * A counter who has assignments sees only their own items in the recount queue.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->json('recount_assignments')->nullable()->after('unit_assignments');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn('recount_assignments');
        });
    }
};
