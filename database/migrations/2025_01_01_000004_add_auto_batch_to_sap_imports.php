<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('sap_imports', function (Blueprint $table) {
            $table->boolean('auto_batch_enrichment')->default(false)->after('prompts');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sap_imports', function (Blueprint $table) {
            $table->dropColumn('auto_batch_enrichment');
        });
    }
};
