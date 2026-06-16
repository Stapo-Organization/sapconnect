<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The ONE B2C event spine — capture-only at launch. The store is essentially
 * pre-launch (cold start), so every exit from the SAP-proxy depends on capturing
 * view/search/add_to_cart/purchase from day one. Consumed later (rollup, CF, LTR).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('store_events', function (Blueprint $table) {
            $table->id();
            $table->string('anon_id', 64)->nullable();
            $table->string('customer_ref')->nullable();
            $table->enum('event_type', ['view', 'search', 'add_to_cart', 'begin_checkout', 'purchase', 'impression']);
            $table->string('item_code')->nullable();
            $table->string('query')->nullable();
            $table->integer('position')->nullable();
            $table->string('zone')->nullable();
            $table->string('ab_variant')->nullable();
            $table->json('payload')->nullable();
            $table->timestamp('occurred_at')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->index('occurred_at');
            $table->index(['event_type', 'item_code']);
            $table->index('anon_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('store_events');
    }
};
