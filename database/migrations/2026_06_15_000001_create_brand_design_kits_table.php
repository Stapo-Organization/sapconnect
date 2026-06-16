<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-brand ad design identity. A single-brand campaign uses its brand's kit
 * (colors / fonts / logo / scene mood); multi-brand or store-feature campaigns
 * fall back to the Zooboxi house kit. Any null column inherits the house default
 * (see App\Services\Marketing\BrandDesignKit::HOUSE), so a row can override just
 * one thing (e.g. only the accent colour).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('brand_design_kits', function (Blueprint $table) {
            $table->id();
            $table->string('brand_key')->unique(); // matches brands.code (or name)
            $table->string('brand_name')->nullable();
            $table->string('accent')->nullable();
            $table->string('accent_dark')->nullable();
            $table->string('gold')->nullable();
            $table->string('headline_font')->nullable(); // family present in resources/fonts
            $table->string('body_font')->nullable();
            $table->string('logo_url')->nullable();       // overrides brands.image_url
            $table->string('scene_style')->nullable();    // appended to the AI scene prompt
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('brand_design_kits');
    }
};
