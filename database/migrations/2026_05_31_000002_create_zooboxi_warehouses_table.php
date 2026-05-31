<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Zooboxi warehouse configuration table.
     * Extends the base warehouses table with GPS coordinates,
     * delivery radius, and store-specific settings.
     */
    public function up(): void
    {
        Schema::create('zooboxi_warehouses', function (Blueprint $table) {
            $table->id();
            $table->string('warehouse_code', 50)->unique()
                ->comment('References warehouses.warehouse_code');
            $table->string('display_name_ar')
                ->comment('Arabic display name for customers');
            $table->string('display_name_en')->nullable()
                ->comment('English display name for customers');
            $table->string('city', 100)
                ->comment('City name for same-day delivery matching');
            $table->text('address_ar')->nullable()
                ->comment('Full Arabic address for pickup');
            $table->text('address_en')->nullable()
                ->comment('Full English address for pickup');
            $table->decimal('latitude', 10, 8)
                ->comment('GPS latitude for distance calculation');
            $table->decimal('longitude', 11, 8)
                ->comment('GPS longitude for distance calculation');
            $table->decimal('express_radius_km', 5, 2)->default(10.00)
                ->comment('Express delivery coverage radius in km');
            $table->boolean('is_central')->default(false)
                ->comment('Central warehouse for the city (same-day delivery)');
            $table->boolean('is_main_hub')->default(false)
                ->comment('Main hub for national shipping fallback');
            $table->boolean('is_pickup_enabled')->default(true)
                ->comment('Whether Click & Collect is available');
            $table->boolean('is_active')->default(true)
                ->comment('Whether this warehouse serves Zooboxi orders');
            $table->json('working_hours')->nullable()
                ->comment('JSON object with daily open/close times');
            $table->string('phone', 20)->nullable();
            $table->timestamps();

            // Index for active warehouse lookups
            $table->index(['is_active', 'city'], 'idx_active_city');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('zooboxi_warehouses');
    }
};
