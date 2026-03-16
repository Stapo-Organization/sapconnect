<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('api_logs', function (Blueprint $table) {
            $table->string('database_name')->nullable()->after('endpoint');
        });
    }

    public function down(): void
    {
        Schema::table('api_logs', function (Blueprint $table) {
            $table->dropColumn('database_name');
        });
    }
};
