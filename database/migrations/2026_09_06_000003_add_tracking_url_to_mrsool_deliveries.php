<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Mrsool sends a `merchant_tracking_link` (portal tracking page) in every
 * webhook / GET payload — keep it so the store and the app can deep-link.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('mrsool_deliveries', function (Blueprint $table) {
            $table->string('tracking_url', 500)->nullable()->after('awb_url');
        });
    }

    public function down(): void
    {
        Schema::table('mrsool_deliveries', function (Blueprint $table) {
            $table->dropColumn('tracking_url');
        });
    }
};
