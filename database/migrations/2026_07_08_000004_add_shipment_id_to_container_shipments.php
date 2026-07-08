<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Durable link from a Traqo container mirror row to the operational Shipment it
 * belongs to — completing the PO → Shipment → Traqo-Container spine.
 *
 * The link lives on the OPERATIONAL side on purpose: `container_shipments` is a
 * disposable Traqo mirror that the sync PRUNES (deletes) when Traqo drops a row.
 * The sync's prune is now guarded to never delete a linked container, but keeping
 * the FK nullable + nullOnDelete means a deleted Shipment simply detaches, never
 * cascades. `purchase_order_ref` (already present) stays as an optional free-text
 * SAP DocNum note; `shipment_id` is the real link.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('container_shipments', function (Blueprint $table) {
            $table->foreignId('shipment_id')->nullable()->after('purchase_order_ref')
                ->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('container_shipments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('shipment_id');
        });
    }
};
