<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Link GRPO lines back to the Purchase Order line each one fulfils.
 *
 * SAP `PurchaseDeliveryNotes` document lines carry BaseEntry/BaseLine/BaseType (the
 * source doc a receipt draws down). BaseType 22 = Purchase Order (OPOR). Storing
 * these lets us join sap_goods_receipt_lines.base_entry → purchase_orders.sap_doc_entry
 * for real ordered-vs-received reconciliation.
 *
 * Backfill: the incremental UpdateDate watermark skips existing receipts, so run
 * `php artisan sap:sync-goods-receipts --full` once after deploy to populate history.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sap_goods_receipt_lines', function (Blueprint $table) {
            $table->unsignedBigInteger('base_entry')->nullable()->after('line_num'); // source PO DocEntry
            $table->integer('base_line')->nullable()->after('base_entry');            // source PO line num
            $table->smallInteger('base_type')->nullable()->after('base_line');        // 22 = OPOR
            $table->index('base_entry');
        });
    }

    public function down(): void
    {
        Schema::table('sap_goods_receipt_lines', function (Blueprint $table) {
            $table->dropIndex(['base_entry']);
            $table->dropColumn(['base_entry', 'base_line', 'base_type']);
        });
    }
};
