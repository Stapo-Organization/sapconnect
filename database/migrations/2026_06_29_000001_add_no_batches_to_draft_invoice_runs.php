<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-run flag to skip batch allocation entirely (e.g. the Panda upload, which
 * the owner wants posted without selecting batches).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('draft_invoice_runs', function (Blueprint $table) {
            $table->boolean('no_batches')->default(false)->after('tax_code');
        });
    }

    public function down(): void
    {
        Schema::table('draft_invoice_runs', function (Blueprint $table) {
            $table->dropColumn('no_batches');
        });
    }
};
