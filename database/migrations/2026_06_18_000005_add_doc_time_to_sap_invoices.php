<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Store SAP invoice DocTime so the Retail Dashboard can bucket "today" by hour
 * (the day-level charts only need doc_date, but hourly needs the time).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sap_invoices', function (Blueprint $table) {
            $table->time('doc_time')->nullable()->after('doc_date');
        });
    }

    public function down(): void
    {
        Schema::table('sap_invoices', function (Blueprint $table) {
            $table->dropColumn('doc_time');
        });
    }
};
