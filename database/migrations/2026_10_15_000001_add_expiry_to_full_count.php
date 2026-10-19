<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Expiry dates in the full count.
 *
 * - inventory_counting_lines.expiries: what the counter read on the packs of
 *   one line, split by date — [{"date":"2027-03","qty":6,"batch":"15/04/2025"}].
 *   A date is Y-m (pack prints month/year) or Y-m-d (a SAP batch date). NULL =
 *   not asked (recount rounds), [] = the counter said the packs carry no date.
 * - inventory_counting_batches: SAP's batches (OBTN/OBTQ via the read-only
 *   `batchesitems` query) for the count's warehouse, frozen with the book
 *   snapshot. The app offers their dates as one-tap choices, and the result
 *   flags shelf dates SAP has no batch for.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_counting_lines', function (Blueprint $table) {
            $table->json('expiries')->nullable()->after('loose');
        });

        Schema::create('inventory_counting_batches', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('inventory_counting_id');
            $table->string('item_code', 64);
            $table->string('batch', 64);
            $table->date('expiry_date')->nullable();
            $table->decimal('quantity', 14, 3)->default(0);
            $table->timestamps();
            $table->unique(['inventory_counting_id', 'item_code', 'batch'], 'icb_session_item_batch');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_counting_batches');
        Schema::table('inventory_counting_lines', function (Blueprint $table) {
            $table->dropColumn('expiries');
        });
    }
};
