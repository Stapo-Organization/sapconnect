<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-campaign design-identity override, chosen by the owner at approval time
 * (PromotionController::approve) and read by App\Services\Marketing\BrandDesignKit::forCampaign():
 *   null    → auto (single brand → that brand's kit; multi/none → Zooboxi store kit)
 *   'brand' → force the featured brand's identity
 *   'zooboxi' → force the Zooboxi store identity
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->string('design_identity', 16)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->dropColumn('design_identity');
        });
    }
};
