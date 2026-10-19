<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Full (wall-to-wall) showroom count.
 *
 * - store_locations: the showroom map — one row per shelf, grouped by unit
 *   (G04 = gondola 4, G04-R2 = its 2nd shelf from the top). A map only: stock
 *   stays item × warehouse in SAP, nothing is tracked per shelf outside a count.
 * - inventory_counting_lines gain where/who/how: the shelf the line was counted
 *   on, the counter, the round (1 count, 2 blind recount, 3 supervisor) and the
 *   carton breakdown (cartons × pack + loose).
 * - inventory_countings gain the full-count phase, unit claims, the SAP book
 *   snapshot status and the approval.
 * - inventory_counting_snapshots: SAP InStock per item frozen when the count
 *   starts, the book quantity every variance is measured against.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('store_locations', function (Blueprint $table) {
            $table->id();
            $table->string('warehouse_code', 32);
            $table->string('code', 32);                 // G04-R2
            $table->string('unit_code', 16);            // G04
            $table->string('kind', 16);                 // gondola|wall|endcap|cashier|backroom|other
            $table->string('name')->nullable();         // «معلبات القطط»
            $table->unsignedSmallInteger('shelf_no');   // 1 = top
            $table->unsignedInteger('sort')->default(0);
            $table->timestamp('labeled_at')->nullable(); // label stuck and scanned
            $table->timestamps();
            $table->unique(['warehouse_code', 'code']);
            $table->index(['warehouse_code', 'unit_code']);
        });

        Schema::table('inventory_counting_lines', function (Blueprint $table) {
            $table->string('location_code', 32)->nullable()->after('piece_barcode');
            $table->unsignedBigInteger('counted_by')->nullable()->after('location_code');
            $table->unsignedTinyInteger('count_round')->default(1)->after('counted_by');
            $table->decimal('cartons', 12, 3)->nullable()->after('count_round');
            $table->decimal('pack_size', 12, 3)->nullable()->after('cartons');
            $table->decimal('loose', 12, 3)->nullable()->after('pack_size');
            $table->index(['inventory_counting_id', 'item_code', 'count_round'], 'icl_session_item_round');
            $table->index(['inventory_counting_id', 'location_code'], 'icl_session_location');
        });

        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->string('phase', 16)->nullable()->after('counting_type');
            $table->json('unit_assignments')->nullable()->after('phase');
            $table->string('snapshot_status', 16)->nullable()->after('unit_assignments');
            $table->timestamp('snapshot_at')->nullable()->after('snapshot_status');
            $table->unsignedBigInteger('approved_by')->nullable()->after('completed_at');
            $table->timestamp('approved_at')->nullable()->after('approved_by');
        });

        Schema::create('inventory_counting_snapshots', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('inventory_counting_id');
            $table->string('item_code', 64);
            $table->decimal('system_qty', 15, 4)->default(0);
            $table->decimal('unit_cost', 15, 4)->nullable();
            $table->timestamps();
            $table->unique(['inventory_counting_id', 'item_code'], 'ics_session_item');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_counting_snapshots');
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn(['phase', 'unit_assignments', 'snapshot_status', 'snapshot_at', 'approved_by', 'approved_at']);
        });
        Schema::table('inventory_counting_lines', function (Blueprint $table) {
            $table->dropIndex('icl_session_item_round');
            $table->dropIndex('icl_session_location');
            $table->dropColumn(['location_code', 'counted_by', 'count_round', 'cartons', 'pack_size', 'loose']);
        });
        Schema::dropIfExists('store_locations');
    }
};
