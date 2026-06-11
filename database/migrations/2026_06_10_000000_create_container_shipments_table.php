<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Local DB snapshot of Traqo ocean-freight shipments (read-only mirror).
 *
 * Filled once daily by `traqo:sync-shipments`. `detail` holds the full nested
 * tracking tables (events / vessels / locations / voyage plan / eta history /
 * containers). `purchase_order_ref` is intentionally nullable now — it is the
 * seam for the planned SAP purchase-order linkage (each Jeddah-bound container
 * is incoming stock against a PO).
 */
return new class extends Migration {
    public function up(): void
    {
        Schema::create('container_shipments', function (Blueprint $table) {
            $table->id();

            // Identity (from Traqo)
            $table->string('name')->unique();              // e.g. SHP-28287
            $table->string('shipment_uid')->nullable()->index();
            $table->string('reference_number')->index();   // container or BL number
            $table->string('shipment_type')->nullable();   // Container / Bill of Lading

            // Carrier
            $table->string('sealine')->nullable();         // SCAC code (CMDU, ...)
            $table->string('sealine_name')->nullable();

            // Lane & status
            $table->string('status')->nullable();          // IN_TRANSIT / DELIVERED / '' (pending)
            $table->string('origin')->nullable();
            $table->string('destination')->nullable();
            $table->dateTime('eta')->nullable();
            $table->integer('total_days')->nullable();
            $table->integer('remaining_days')->nullable();
            $table->unsignedSmallInteger('number_of_containers')->default(0);
            $table->boolean('is_active')->default(true);
            $table->boolean('is_delayed')->default(false); // raw Traqo flag (unreliable — we recompute)

            // Live position + route
            $table->decimal('latitude', 10, 6)->nullable();
            $table->decimal('longitude', 10, 6)->nullable();
            $table->longText('route_json')->nullable();

            // Full nested tracking tables (events/vessels/locations/voyage/etc.)
            $table->json('detail')->nullable();

            // Sharing / provenance
            $table->string('shipment_public_url')->nullable();
            $table->dateTime('remote_synced_at')->nullable();  // Traqo's last_synced_at
            $table->dateTime('detail_fetched_at')->nullable(); // when WE last pulled detail
            $table->dateTime('fetched_at')->nullable();        // when WE last saw it in the list

            // Future SAP linkage (kept nullable until the SAP join lands)
            $table->string('purchase_order_ref')->nullable()->index();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('container_shipments');
    }
};
