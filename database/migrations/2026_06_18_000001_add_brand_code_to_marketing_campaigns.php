<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Brand-page campaigns are tied to a BRAND (App\Models\Brand.code) rather than a
 * single product — they power the per-brand boutique pages on the store
 * (/brand/<slug>/). A null brand_code keeps the existing product-centric
 * campaigns unchanged. One active campaign per (placement, brand_code).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->string('brand_code')->nullable()->after('item_code');
            $table->index(['brand_code', 'placement']);
        });
    }

    public function down(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->dropIndex(['brand_code', 'placement']);
            $table->dropColumn('brand_code');
        });
    }
};
