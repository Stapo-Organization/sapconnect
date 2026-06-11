<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Permanent ledger of every container/BL number ever SUBMITTED to Traqo for
 * tracking — the core anti-duplicate guard for the auto-track automation.
 *
 * The UNIQUE constraint on `container_number` makes re-registration impossible:
 * once a number is here (any status), auto-track will never submit it again,
 * even if Traqo later loses/deletes/delivers it and it drops off /shipments.
 * This is the safeguard that was missing when WHSU8376691 ballooned to 16 slots.
 *
 * Seeded on creation from the numbers already tracked in container_shipments
 * (marked `preexisting`) so nothing currently live can ever be re-added.
 */
return new class extends Migration {
    public function up(): void
    {
        Schema::create('traqo_track_requests', function (Blueprint $table) {
            $table->id();
            $table->string('container_number')->unique();   // normalized UPPER — the hard anti-dup key
            $table->string('sealine')->nullable();           // SCAC hint if known
            $table->string('shipment_type')->default('Container'); // Container | Bill of Lading
            $table->string('source')->default('auto');       // auto | manual | preexisting
            $table->string('status')->default('pending');    // pending | tracked | failed | preexisting
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->string('response_status')->nullable();   // status Traqo returned (IN_TRANSIT/…)
            $table->string('note')->nullable();              // failure reason / context
            $table->unsignedInteger('sheet_row')->nullable();// originating Google-Sheet row, if any
            $table->dateTime('registered_at')->nullable();   // when Traqo accepted it
            $table->timestamps();

            $table->index(['source', 'created_at']); // monthly-budget counting
            $table->index('status');
        });

        // Seed from what's already tracked so live shipments are never re-added.
        if (Schema::hasTable('container_shipments')) {
            $now = now();
            $seen = [];
            foreach (DB::table('container_shipments')->select('reference_number')->get() as $row) {
                $cn = strtoupper(trim((string) $row->reference_number));
                if ($cn === '' || isset($seen[$cn])) {
                    continue;
                }
                $seen[$cn] = true;
                DB::table('traqo_track_requests')->insert([
                    'container_number' => $cn,
                    'source'           => 'preexisting',
                    'status'           => 'preexisting',
                    'attempts'         => 1,
                    'note'             => 'seeded from existing mirror',
                    'registered_at'    => $now,
                    'created_at'       => $now,
                    'updated_at'       => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('traqo_track_requests');
    }
};
