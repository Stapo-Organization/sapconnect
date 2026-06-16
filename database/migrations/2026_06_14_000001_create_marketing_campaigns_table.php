<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Owner-approved, AI-generated, channel-safe ad campaigns. Suggested daily by
 * marketing:suggest-campaigns from the existing intelligence; nothing publishes
 * until the owner approves in the app. Status/scope kept as strings (portable
 * across sqlite/MySQL + future-proof). Performance counters are a cache derived
 * from store_events — never an input to offer sizing.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('marketing_campaigns', function (Blueprint $table) {
            $table->id();
            $table->string('campaign_type');                 // spotlight|clearance|bundle|new_arrival|express
            $table->string('scope')->default('visibility');  // visibility|coupon|bundle
            $table->string('source')->default('auto_daily'); // auto_daily|manual

            $table->string('item_code')->nullable();
            $table->json('companion_item_codes')->nullable(); // bundle/FBT members
            $table->string('objective')->nullable();
            $table->string('reason')->nullable();

            // Arabic copy (owner-editable at approval)
            $table->string('headline_ar')->nullable();
            $table->string('subheadline_ar')->nullable();
            $table->string('cta_ar')->nullable();
            $table->string('badge_ar')->nullable();

            // Offer (channel-safe: WC-native coupon only, never SAP/_sale_price)
            $table->string('coupon_code')->nullable();
            $table->unsignedBigInteger('coupon_wc_id')->nullable();
            $table->decimal('discount_pct', 5, 2)->nullable();
            $table->decimal('floor_price', 15, 4)->nullable();        // max(cost*1.10, retail*1.00) snapshot
            $table->decimal('base_price', 15, 4)->nullable();         // current effective price at approval
            $table->decimal('effective_price_min', 15, 4)->nullable();// worst-case post-coupon price

            // Placement & targeting
            $table->json('zones')->nullable();
            $table->string('target_city')->nullable();
            $table->boolean('target_express_only')->default(false);
            $table->boolean('ab_enabled')->default(false);
            $table->integer('priority')->default(0);

            // Schedule & lifecycle
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->string('status')->default('suggested'); // suggested|approved|scheduled|active|ended|rejected|failed

            // Why suggested + the creative brief
            $table->decimal('score', 8, 3)->nullable();
            $table->json('rationale')->nullable();
            $table->json('brief')->nullable();

            // Approval audit (owner = user id, enforced by marketing.approve gate)
            $table->unsignedBigInteger('owner_approved_by')->nullable();
            $table->timestamp('owner_approved_at')->nullable();
            $table->string('rejected_reason')->nullable();
            $table->timestamp('published_at')->nullable();

            // Performance cache (display-only; derived from store_events)
            $table->unsignedInteger('impressions')->default(0);
            $table->unsignedInteger('clicks')->default(0);
            $table->unsignedInteger('add_to_carts')->default(0);
            $table->unsignedInteger('purchases')->default(0);
            $table->decimal('revenue', 15, 4)->default(0);
            $table->timestamp('perf_synced_at')->nullable();

            $table->timestamp('computed_at')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('item_code');
            $table->index(['status', 'starts_at', 'ends_at']);
            $table->index(['item_code', 'campaign_type']); // dedup of open suggestions
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('marketing_campaigns');
    }
};
