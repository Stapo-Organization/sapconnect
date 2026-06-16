<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Channel-safe clearance queue. Ranks the worst trapped capital first (LPS) so the
 * owner attacks the 57M-SAR overstock by ROI. Muntajat is the master wholesaler, so
 * discounts NEVER auto-apply and the default floor is the retail price (no market
 * break) — the markdown ladder is suggest-only and owner-approved. Excludes
 * starved/stockout items (those are reorder, not clearance).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('clearance_campaigns', function (Blueprint $table) {
            $table->id();
            $table->string('item_code')->unique();
            $table->enum('reason', ['dead', 'overstock', 'never_sold']);
            $table->decimal('lps', 6, 2)->default(0); // liquidation priority score
            $table->decimal('capital_tied_sar', 15, 2)->default(0);
            $table->decimal('days_of_cover', 15, 2)->nullable();
            $table->integer('stagnation_days')->nullable();
            $table->decimal('retail_price', 15, 4)->nullable();
            $table->decimal('cost_proxy', 15, 4)->nullable();
            $table->enum('cost_confidence', ['actual', 'brand_est', 'category_est'])->nullable();
            $table->decimal('floor_price', 15, 4)->nullable();        // never sell below this
            $table->decimal('recommended_discount_pct', 5, 2)->default(0); // 0 = channel-safe default
            $table->decimal('recommended_sale_price', 15, 4)->nullable();
            $table->enum('status', ['suggested', 'active', 'ended'])->default('suggested');
            $table->unsignedBigInteger('owner_approved_by')->nullable();
            $table->timestamp('owner_approved_at')->nullable();
            $table->timestamp('computed_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'lps']);
            $table->index('reason');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('clearance_campaigns');
    }
};
