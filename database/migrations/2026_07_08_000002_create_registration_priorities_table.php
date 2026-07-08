<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Brand-level SFDA registration priority — the "FDA Registration Priority" tab.
 *
 * Keyed by `brand_code` STRING (not a column on `brands`) on purpose: `brands` is
 * SAP-synced taxonomy whose Eloquent model swaps between `brands` / `brands_test`
 * by the active SAP session DB, so an operational column there would be invisible
 * on the test DB and could be wiped on re-sync. A tiny side table stays correct
 * across environments and in CLI (no session).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('registration_priorities', function (Blueprint $table) {
            $table->id();
            $table->string('brand_code')->unique(); // matches products.items_group_code / brands.code (as string)
            $table->unsignedInteger('priority')->default(0);
            $table->string('brand_name')->nullable(); // human label snapshot
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('registration_priorities');
    }
};
