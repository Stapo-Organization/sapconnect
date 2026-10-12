<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * بوابة كتالوج زوبوكسي — the automatic path from "new SAP item" to "live on
 * store.zooboxi.com". Until now `zooboxi_active` was set only by the one-off
 * Zid import (2025-12) or a hand toggle, so every item created since never
 * reached the store. The gate evaluates readiness on a schedule and records
 * WHY a product is held, so the owner sees a queue with reasons instead of
 * silence.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // pending | active | held | blocked  (blocked = owner said never)
            $table->string('zooboxi_gate_status', 16)->default('pending')->index();
            // machine reasons the gate held the product: ["no_image","no_price"]
            $table->json('zooboxi_gate_reasons')->nullable();
            $table->timestamp('zooboxi_gate_checked_at')->nullable();
            $table->timestamp('zooboxi_activated_at')->nullable();
            // who wrote zb_* content: zid | sap | shipgo | ai | manual
            $table->string('zb_content_source', 16)->nullable();
            $table->timestamp('zb_content_at')->nullable();
            // resolved picture list the gate verified (HTTP 200), newest first
            $table->json('zb_resolved_images')->nullable();
        });

        Schema::create('zooboxi_gate_events', function (Blueprint $table) {
            $table->id();
            $table->string('item_code', 50)->index();
            // activated | held | blocked | unblocked | content | error
            $table->string('action', 16)->index();
            $table->json('reasons')->nullable();
            $table->string('note', 500)->nullable();
            $table->timestamp('created_at')->useCurrent()->index();
        });

        // Everything already live keeps its status — the gate never re-judges it.
        \Illuminate\Support\Facades\DB::table('products')
            ->where('zooboxi_active', true)
            ->update(['zooboxi_gate_status' => 'active', 'zb_content_source' => 'zid']);
    }

    public function down(): void
    {
        Schema::dropIfExists('zooboxi_gate_events');
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn([
                'zooboxi_gate_status', 'zooboxi_gate_reasons', 'zooboxi_gate_checked_at',
                'zooboxi_activated_at', 'zb_content_source', 'zb_content_at', 'zb_resolved_images',
            ]);
        });
    }
};
