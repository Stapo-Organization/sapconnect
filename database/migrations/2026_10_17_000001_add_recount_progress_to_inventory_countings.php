<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Full count: recounts in progress — {item_code: {round, user_id, user_name, at}}.
 * A recount stays open (its lines provisional) until the counter says they have
 * covered every place the item sits, so one wrong shelf no longer settles it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->json('recount_progress')->nullable()->after('recount_assignments');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn('recount_progress');
        });
    }
};
