<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-branch "Showroom Pulse" health score (0-100) + the four vital signs
 * behind it, plus the cross-branch ranking. Built DB-only by
 * `intelligence:build-branch-pulse` from branch_product_intelligence,
 * sap_invoice_lines (basket size) and product_abc_classifications (count
 * accuracy). One row per warehouse.
 *
 * Vitals are RATES (0-100) so big and small branches rank fairly; the score is
 * a tunable weighted blend (weights live in zooboxi_settings: pulse_w_*).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_pulse_scores', function (Blueprint $table) {
            $table->id();
            $table->string('warehouse_code')->unique();

            // Composite (0-100) + previous snapshot for the trend arrow
            $table->decimal('score', 6, 2)->default(0);
            $table->decimal('score_prev', 6, 2)->nullable();

            // The four vital signs (each a 0-100 rate)
            $table->decimal('vital_hero_availability', 6, 2)->default(0);
            $table->decimal('vital_capital_efficiency', 6, 2)->default(0);
            $table->decimal('vital_basket_size', 6, 2)->default(0);
            $table->decimal('vital_count_accuracy', 6, 2)->nullable(); // null = branch not cycle-counted yet (excluded from score)

            // Raw basket size (avg items/invoice) shown alongside the normalized vital
            $table->decimal('basket_items_per_invoice', 8, 2)->default(0);

            // Headline money figures for the levers (this branch)
            $table->decimal('bleeding_monthly_sar', 15, 2)->default(0);   // 🔴 lost sales / month
            $table->decimal('trapped_capital_sar', 15, 2)->default(0);    // 🟡 dead + overstock capital

            // Cross-branch ranking
            $table->unsignedInteger('rank')->nullable();
            $table->unsignedInteger('total_branches')->nullable();

            $table->timestamp('computed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_pulse_scores');
    }
};
