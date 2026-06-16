<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The ONE cost service for Zooboxi pricing/margin/clearance floors.
 * Seeded (DB-only) from `sap_goods_receipt_lines` actual purchase cost.
 * `cost_confidence='actual'` only where a real GRPO cost exists — automatic
 * markdowns (later) are gated to that, protecting against selling below cost.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_costs', function (Blueprint $table) {
            $table->id();
            $table->string('item_code')->unique();
            $table->decimal('cost_proxy_sar', 15, 4)->default(0);
            $table->enum('cost_confidence', ['actual', 'brand_est', 'category_est'])->default('category_est');
            $table->string('source')->nullable(); // grpo | brand_median | category_default
            $table->decimal('brand_median_margin', 8, 4)->nullable();
            $table->timestamp('computed_at')->nullable();
            $table->timestamps();

            $table->index('cost_confidence');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_costs');
    }
};
