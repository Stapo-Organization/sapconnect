<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-branch (per-warehouse) demand & health intelligence — the data spine
 * behind نبض المعرض (Showroom Pulse). Built DB-only by
 * `intelligence:build-branch-products` from C0000001 retail sales, this
 * warehouse's stock, GRPO arrivals and product_costs.
 *
 * Sibling of `product_intelligence` (which stores the GLOBAL item-level rollup,
 * warehouse_code=''); this table carries one row per (item, real warehouse) so a
 * branch manager sees the state of THEIR showroom, not the company total. Only
 * items the warehouse actually holds or has sold get a row.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_product_intelligence', function (Blueprint $table) {
            $table->id();
            $table->string('item_code');
            $table->string('warehouse_code'); // real branch code (never '')

            // Demand (consumer pieces/day, from C0000001, scoped to this warehouse)
            $table->decimal('ads_30', 15, 4)->default(0);
            $table->decimal('ads_90', 15, 4)->default(0);
            $table->decimal('velocity_blended', 15, 4)->default(0);
            $table->enum('demand_class', ['fast', 'intermittent', 'new', 'dead'])->default('new');
            $table->date('last_sale_date')->nullable();
            $table->boolean('is_never_sold')->default(false);

            // Stock & cover (this warehouse)
            $table->decimal('current_stock', 15, 4)->default(0);
            $table->decimal('days_of_cover', 15, 2)->nullable();

            // Stockout-corrected (window reconstruction: GRPO arrivals + sales, this warehouse)
            $table->decimal('in_stock_rate', 8, 4)->default(1);
            $table->decimal('v_true', 15, 4)->default(0);
            $table->decimal('lost_sales_monthly', 15, 4)->default(0);

            // Health
            $table->enum('health_status', ['dead', 'overstock', 'healthy', 'low', 'stockout', 'starved'])->default('healthy');
            $table->decimal('excess_units', 15, 4)->default(0);

            // Economics
            $table->decimal('unit_cost_sar', 15, 4)->nullable();
            $table->decimal('unit_retail_sar', 15, 4)->nullable();
            $table->decimal('capital_at_risk_sar', 15, 2)->default(0);

            // Classification
            $table->char('abc_class', 1)->nullable();
            $table->boolean('is_hero')->default(false);
            $table->timestamp('computed_at')->nullable();
            $table->timestamps();

            $table->unique(['item_code', 'warehouse_code'], 'bpi_item_wh_unique');
            $table->index(['warehouse_code', 'health_status'], 'bpi_wh_health_idx');
            $table->index(['warehouse_code', 'is_hero'], 'bpi_wh_hero_idx');
            $table->index(['warehouse_code', 'capital_at_risk_sar'], 'bpi_wh_capital_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_product_intelligence');
    }
};
