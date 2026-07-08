<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Two operational fields the "Arrived Shipments" tab tracked but the schema lacked:
 *  - commercial_invoice_no: the SUPPLIER's commercial invoice number. Distinct from
 *    the existing freight_invoice_no / clearance_invoice_no / customs_manifest_no.
 *  - announcement_no: the actual announcement (إعلان) number. The existing
 *    `is_announced` boolean stays as a quick flag; this stores the real number.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->string('commercial_invoice_no')->nullable()->after('customs_manifest_no');
            $table->string('announcement_no')->nullable()->after('is_announced');
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table) {
            $table->dropColumn(['commercial_invoice_no', 'announcement_no']);
        });
    }
};
