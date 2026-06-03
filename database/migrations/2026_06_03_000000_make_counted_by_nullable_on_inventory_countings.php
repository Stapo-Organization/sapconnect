<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Cycle-plan sessions are generated before anyone counts them, so the
     * counter (counted_by) is unknown at creation time. Allow NULL and set
     * it only once a user submits the count.
     */
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropForeign(['counted_by']);
        });

        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->foreignId('counted_by')->nullable()->change();
            $table->foreign('counted_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropForeign(['counted_by']);
        });

        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->foreignId('counted_by')->nullable(false)->change();
            $table->foreign('counted_by')->references('id')->on('users')->cascadeOnDelete();
        });
    }
};
