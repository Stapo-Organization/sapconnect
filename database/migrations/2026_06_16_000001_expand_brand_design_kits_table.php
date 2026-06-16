<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Expands brand_design_kits from a 6-field colour/font override into a full,
 * researched advertising "Brand Kit" per brand: identity (country/founded/
 * positioning/audience/tagline), the all-important imagery_style (real photos
 * vs illustration vs hybrid), Arabic typography direction, mood, brand don'ts,
 * research provenance (confidence/sources). Every column stays nullable so a
 * row still inherits the Zooboxi HOUSE default for anything it doesn't set
 * (see App\Services\Marketing\BrandDesignKit::HOUSE).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('brand_design_kits', function (Blueprint $table) {
            $table->string('country')->nullable()->after('brand_name');
            $table->string('founded')->nullable()->after('country');
            $table->string('category')->nullable()->after('founded');         // cat,dog,bird,small_pet,...
            $table->string('positioning')->nullable()->after('category');      // super_premium,premium,mid,value
            $table->string('tagline_en')->nullable()->after('positioning');
            $table->string('tagline_ar')->nullable()->after('tagline_en');
            $table->text('audience_ar')->nullable()->after('tagline_ar');

            // The heart of the kit: how the brand depicts things visually.
            $table->string('imagery_style')->nullable()->after('audience_ar'); // photographic|illustration|hybrid
            $table->text('imagery_notes')->nullable()->after('imagery_style');

            $table->string('text_style_ar')->nullable()->after('body_font');   // Arabic typography direction for the AI
            $table->string('mood_ar')->nullable()->after('text_style_ar');
            $table->text('do_not_ar')->nullable()->after('mood_ar');
            $table->text('palette_notes')->nullable()->after('gold');

            $table->string('confidence')->nullable()->after('scene_style');    // high|medium|low (research confidence)
            $table->json('sources')->nullable()->after('confidence');
        });
    }

    public function down(): void
    {
        Schema::table('brand_design_kits', function (Blueprint $table) {
            $table->dropColumn([
                'country', 'founded', 'category', 'positioning',
                'tagline_en', 'tagline_ar', 'audience_ar',
                'imagery_style', 'imagery_notes',
                'text_style_ar', 'mood_ar', 'do_not_ar', 'palette_notes',
                'confidence', 'sources',
            ]);
        });
    }
};
