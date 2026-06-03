<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Cron-generated cycle sessions have counted_by = null until completed.
     * Record who actually executes a session (first scan) so gamification can
     * attribute points to the right branch manager.
     */
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->unsignedBigInteger('started_by')->nullable()->after('counted_by');
            $table->timestamp('started_at')->nullable()->after('started_by');

            $table->foreign('started_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropForeign(['started_by']);
            $table->dropColumn(['started_by', 'started_at']);
        });
    }
};
