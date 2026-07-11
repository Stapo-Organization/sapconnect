<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Covering indexes for the sales-channel dashboards (retail vs wholesale).
 *
 * The channel queries slice invoice/credit-memo HEADERS by date range and
 * card_code (retail = C0000001, wholesale = everything else), summing
 * doc_total. Neither table had an index on doc_date or card_code, so a full
 * year scan walked every row. doc_date leads because the wholesale predicate
 * is an inequality on card_code (an index leading with card_code can't serve
 * `card_code <> ?` range scans); doc_total makes the sums index-only.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sap_invoices', function (Blueprint $table) {
            $table->index(['doc_date', 'card_code', 'doc_total'], 'idx_inv_date_card_total');
        });
        Schema::table('sap_credit_memos', function (Blueprint $table) {
            $table->index(['doc_date', 'card_code', 'doc_total'], 'idx_cm_date_card_total');
        });
    }

    public function down(): void
    {
        Schema::table('sap_invoices', function (Blueprint $table) {
            $table->dropIndex('idx_inv_date_card_total');
        });
        Schema::table('sap_credit_memos', function (Blueprint $table) {
            $table->dropIndex('idx_cm_date_card_total');
        });
    }
};
