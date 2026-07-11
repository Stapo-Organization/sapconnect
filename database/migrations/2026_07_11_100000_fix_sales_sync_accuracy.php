<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fix sales-sync accuracy: three structural gaps that cause sapconnect totals
 * to diverge from the SAP HANA query the owner uses.
 *
 *  1. line_num   — SAP's per-document line ordinal. Without it the composite
 *                  key (sap_invoice_id, item_code, warehouse_code) collapses
 *                  duplicate lines into one, losing revenue.
 *  2. ocr_code   — SAP's CostingCode (cost-center / branch), enables the same
 *                  branch-level grouping the owner's HANA query uses.
 *  3. cancelled  — mirrors SAP's CANCELED flag so we can exclude canceled docs
 *                  the way the HANA query does (CANCELED = 'N').
 */
return new class extends Migration
{
    public function up(): void
    {
        // ── sap_invoice_lines ─────────────────────────────────────
        Schema::table('sap_invoice_lines', function (Blueprint $table) {
            $table->integer('line_num')->nullable()->after('sap_invoice_id');
            $table->string('ocr_code', 20)->nullable()->after('warehouse_code');
        });

        // ── sap_credit_memo_lines ─────────────────────────────────
        Schema::table('sap_credit_memo_lines', function (Blueprint $table) {
            $table->integer('line_num')->nullable()->after('sap_credit_memo_id');
            $table->string('ocr_code', 20)->nullable()->after('warehouse_code');
        });

        // ── sap_invoices (cancelled flag) ─────────────────────────
        Schema::table('sap_invoices', function (Blueprint $table) {
            $table->string('cancelled', 5)->default('N')->after('doc_total');
        });

        // ── sap_credit_memos (cancelled flag) ─────────────────────
        Schema::table('sap_credit_memos', function (Blueprint $table) {
            $table->string('cancelled', 5)->default('N')->after('doc_total');
        });
    }

    public function down(): void
    {
        Schema::table('sap_invoice_lines', function (Blueprint $table) {
            $table->dropColumn(['line_num', 'ocr_code']);
        });
        Schema::table('sap_credit_memo_lines', function (Blueprint $table) {
            $table->dropColumn(['line_num', 'ocr_code']);
        });
        Schema::table('sap_invoices', function (Blueprint $table) {
            $table->dropColumn('cancelled');
        });
        Schema::table('sap_credit_memos', function (Blueprint $table) {
            $table->dropColumn('cancelled');
        });
    }
};
