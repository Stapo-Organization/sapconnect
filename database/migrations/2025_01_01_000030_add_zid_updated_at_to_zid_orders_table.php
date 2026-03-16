<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('zid_orders', function (Blueprint $table) {
            $table->timestamp('zid_updated_at')->nullable()->after('order_date');
        });
    }

    public function down(): void
    {
        Schema::table('zid_orders', function (Blueprint $table) {
            $table->dropColumn('zid_updated_at');
        });
    }
};
