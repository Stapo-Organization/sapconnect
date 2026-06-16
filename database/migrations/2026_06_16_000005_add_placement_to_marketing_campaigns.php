<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The store slot the owner assigned the campaign to (see App\Services\Marketing\
 * AdPlacements). Drives the single creative format/size that gets generated on
 * approval, and which zone the store renders it in. One active campaign per slot.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->string('placement')->nullable()->after('zones');
        });
    }

    public function down(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->dropColumn('placement');
        });
    }
};
