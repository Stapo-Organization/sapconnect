<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Stock transfers SAP posted directly (no request behind them) now sit beside
 * the requests so the receiving branch confirms them in the app. Requests and
 * transfers have their own DocEntry series, so the type joins the unique key.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->string('doc_type', 20)->default('request')->after('doc_entry');
        });
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->dropUnique('unique_transfer_db');
            $table->unique(['doc_entry', 'sap_database', 'doc_type'], 'unique_transfer_db_type');
        });
    }

    public function down(): void
    {
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->dropUnique('unique_transfer_db_type');
        });
        \Illuminate\Support\Facades\DB::table('sap_stock_transfers')->where('doc_type', '!=', 'request')->delete();
        Schema::table('sap_stock_transfers', function (Blueprint $table) {
            $table->unique(['doc_entry', 'sap_database'], 'unique_transfer_db');
            $table->dropColumn('doc_type');
        });
    }
};
