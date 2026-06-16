<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Capture SAP's actual per-line economics so the Retail Dashboard can show
 * REAL gross profit (not an estimate). SAP B1 invoice/credit-note lines carry
 * GrossProfit (actual profit at posting), GrossBuyPrice (cost at sale) and
 * LineTotal (ex-VAT revenue) — we were fetching but discarding them.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sap_invoice_lines', function (Blueprint $table) {
            $table->decimal('line_revenue', 15, 4)->nullable()->after('quantity'); // LineTotal, ex-VAT
            $table->decimal('unit_cost', 15, 4)->nullable()->after('line_revenue'); // GrossBuyPrice
            $table->decimal('gross_profit', 15, 4)->nullable()->after('unit_cost'); // GrossProfit, ex-VAT
        });

        Schema::table('sap_credit_memo_lines', function (Blueprint $table) {
            $table->decimal('line_revenue', 15, 4)->nullable()->after('quantity');
            $table->decimal('gross_profit', 15, 4)->nullable()->after('line_revenue');
        });
    }

    public function down(): void
    {
        Schema::table('sap_invoice_lines', function (Blueprint $table) {
            $table->dropColumn(['line_revenue', 'unit_cost', 'gross_profit']);
        });
        Schema::table('sap_credit_memo_lines', function (Blueprint $table) {
            $table->dropColumn(['line_revenue', 'gross_profit']);
        });
    }
};
