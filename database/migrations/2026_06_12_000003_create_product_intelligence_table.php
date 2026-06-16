<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The single Zooboxi intelligence table every store feature reads (ranking,
 * clearance, recommendations, substitutes). Built DB-only by `intelligence:build-products`
 * from C0000001 retail sales + warehouse stock + imported GRPO movements + product_costs.
 *
 * v1 stores item-level rollup rows (warehouse_code=''). Velocity & stock are in the
 * same inventory unit (pieces) — verified — so no sales_items_per_unit conversion.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_intelligence', function (Blueprint $table) {
            $table->id();
            $table->string('item_code');
            $table->string('warehouse_code')->default(''); // '' = item-level rollup

            // Demand (consumer pieces/day, from C0000001)
            $table->decimal('ads_30', 15, 4)->default(0);
            $table->decimal('ads_90', 15, 4)->default(0);
            $table->decimal('velocity_blended', 15, 4)->default(0);
            $table->enum('demand_class', ['fast', 'intermittent', 'new', 'dead'])->default('new');
            $table->date('last_sale_date')->nullable();
            $table->boolean('is_never_sold')->default(false);

            // Stock & cover
            $table->decimal('current_stock', 15, 4)->default(0);
            $table->decimal('days_of_cover', 15, 2)->nullable();

            // Stockout-corrected (90d reconstruction from GRPO arrivals + all sales)
            $table->decimal('in_stock_rate', 8, 4)->default(1); // 0..1 fraction of last 90d in stock
            $table->decimal('v_true', 15, 4)->default(0);       // sold / in-stock-days
            $table->decimal('lost_sales_monthly', 15, 4)->default(0);

            // Health
            $table->enum('health_status', ['dead', 'overstock', 'healthy', 'low', 'stockout', 'starved'])->default('healthy');
            $table->decimal('excess_units', 15, 4)->default(0);

            // Economics
            $table->decimal('unit_cost_sar', 15, 4)->nullable();
            $table->decimal('unit_retail_sar', 15, 4)->nullable();
            $table->decimal('capital_at_risk_sar', 15, 2)->default(0);

            // Classification & ranking
            $table->char('abc_class', 1)->nullable();
            $table->boolean('is_hero')->default(false);
            $table->decimal('composite_rank_score', 8, 4)->default(0);
            $table->string('score_version')->nullable();
            $table->timestamp('computed_at')->nullable();
            $table->timestamps();

            $table->unique(['item_code', 'warehouse_code']);
            $table->index('health_status');
            $table->index('demand_class');
            $table->index('composite_rank_score');
            $table->index(['warehouse_code', 'health_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_intelligence');
    }
};
