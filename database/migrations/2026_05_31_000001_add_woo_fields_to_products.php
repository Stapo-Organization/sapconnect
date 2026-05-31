<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Zooboxi WooCommerce Integration
     * Add woo_sync flag and tracking fields to products table
     */
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->boolean('woo_sync')->default(false)->after('u_proprt5')
                ->comment('Whether this product is published to WooCommerce');
            $table->unsignedBigInteger('woo_product_id')->nullable()->after('woo_sync')
                ->comment('WooCommerce product ID');
            $table->timestamp('woo_synced_at')->nullable()->after('woo_product_id')
                ->comment('Last WooCommerce sync timestamp');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['woo_sync', 'woo_product_id', 'woo_synced_at']);
        });
    }
};
