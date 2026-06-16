<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Rendered ad creatives per campaign: one row per (format, A/B variant). The AI
 * visual base + the composited final banner. A creative is renderable in the
 * store ONLY when status='approved' (the owner selected it). content_hash makes
 * generation idempotent and includes the resolved offer/copy so an edited offer
 * forces a re-composite.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('campaign_creatives', function (Blueprint $table) {
            $table->id();
            $table->foreignId('campaign_id')->constrained('marketing_campaigns')->cascadeOnDelete();

            $table->string('format');               // hero|wide|card|strip
            $table->string('variant', 1)->default('A'); // mirrors store_events.ab_variant
            $table->string('status')->default('queued'); // queued|generating|ready|failed|selected|approved|rejected
            $table->string('driver')->nullable();

            $table->string('base_image_url')->nullable(); // AI visual base (pre-composite)
            $table->string('final_url')->nullable();      // composited banner
            $table->string('thumb_url')->nullable();

            $table->string('headline_ar')->nullable();
            $table->string('subheadline_ar')->nullable();
            $table->string('cta_ar')->nullable();
            $table->string('badge_ar')->nullable();

            $table->text('prompt')->nullable();
            $table->json('generation_meta')->nullable();
            $table->string('content_hash')->nullable();
            $table->text('error')->nullable();
            $table->unsignedTinyInteger('attempts')->default(0);

            $table->timestamps();

            $table->unique(['campaign_id', 'format', 'variant']);
            $table->index('content_hash');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('campaign_creatives');
    }
};
