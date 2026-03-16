<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('sap_imports', function (Blueprint $table) {
            $table->json('prompts')->nullable()->after('mapping');
        });
    }

    public function down(): void
    {
        Schema::table('sap_imports', function (Blueprint $table) {
            $table->dropColumn('prompts');
        });
    }
};
