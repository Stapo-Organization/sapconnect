<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add Zooboxi rich data fields (sourced from ZID) to products table.
     * These fields store the ZID content that makes products ready for the Zooboxi store.
     * zooboxi_active = true means this product should be displayed in the Zooboxi WooCommerce store.
     */
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // Master flag: is this product active in Zooboxi store?
            $table->boolean('zooboxi_active')->default(false)->after('woo_synced_at')
                ->comment('Whether this product is active in the Zooboxi store (has ZID data)');

            // Names (bilingual)
            $table->string('zb_name_ar', 500)->nullable()->after('zooboxi_active');
            $table->string('zb_name_en', 500)->nullable()->after('zb_name_ar');

            // Descriptions (bilingual, can be long HTML)
            $table->longText('zb_description_ar')->nullable()->after('zb_name_en');
            $table->longText('zb_description_en')->nullable()->after('zb_description_ar');
            $table->text('zb_short_description_ar')->nullable()->after('zb_description_en');
            $table->text('zb_short_description_en')->nullable()->after('zb_short_description_ar');

            // Categories (stored as comma-separated paths like "قطط > طعام جاف")
            $table->text('zb_categories_ar')->nullable()->after('zb_short_description_en');
            $table->text('zb_categories_en')->nullable()->after('zb_categories_ar');

            // SEO & Keywords
            $table->string('zb_keywords', 1000)->nullable()->after('zb_categories_en');
            $table->string('zb_seo_title_ar', 500)->nullable()->after('zb_keywords');
            $table->text('zb_seo_description_ar')->nullable()->after('zb_seo_title_ar');
            $table->string('zb_seo_title_en', 500)->nullable()->after('zb_seo_description_ar');
            $table->text('zb_seo_description_en')->nullable()->after('zb_seo_title_en');

            // Images (JSON array of URLs)
            $table->json('zb_images')->nullable()->after('zb_seo_description_en');

            // Weight
            $table->decimal('zb_weight', 10, 3)->nullable()->after('zb_images');
            $table->string('zb_weight_unit', 10)->nullable()->after('zb_weight');

            // Index for fast filtering
            $table->index('zooboxi_active');
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropIndex(['zooboxi_active']);
            $table->dropColumn([
                'zooboxi_active',
                'zb_name_ar', 'zb_name_en',
                'zb_description_ar', 'zb_description_en',
                'zb_short_description_ar', 'zb_short_description_en',
                'zb_categories_ar', 'zb_categories_en',
                'zb_keywords',
                'zb_seo_title_ar', 'zb_seo_description_ar',
                'zb_seo_title_en', 'zb_seo_description_en',
                'zb_images',
                'zb_weight', 'zb_weight_unit',
            ]);
        });
    }
};
