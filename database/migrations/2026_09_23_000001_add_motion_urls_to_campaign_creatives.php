<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Motion engine outputs per creative: the animated SVG (store zones, inline) and the animated WebP
 * (app image slot). final_url stays the static PNG so every existing consumer keeps working.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('campaign_creatives', function (Blueprint $table) {
            $table->string('anim_svg_url')->nullable()->after('thumb_url');
            $table->string('anim_webp_url')->nullable()->after('anim_svg_url');
        });
    }

    public function down(): void
    {
        Schema::table('campaign_creatives', function (Blueprint $table) {
            $table->dropColumn(['anim_svg_url', 'anim_webp_url']);
        });
    }
};
