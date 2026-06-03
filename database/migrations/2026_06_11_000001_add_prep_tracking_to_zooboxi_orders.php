<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Track who prepared an express Zooboxi order and whether the "ready" status
 * was pushed back to the WooCommerce store. Additive only.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('zooboxi_orders', function (Blueprint $table) {
            $table->foreignId('prepared_by')
                ->nullable()
                ->after('sap_synced_at')
                ->constrained('users')
                ->nullOnDelete()
                ->comment('Branch manager who marked the order prepared');
            $table->timestamp('prepared_at')->nullable()->after('prepared_by')
                ->comment('When the order was marked prepared in the app');
            $table->timestamp('woo_status_synced_at')->nullable()->after('prepared_at')
                ->comment('Last successful push of the order status to WooCommerce (null + ready = push pending)');
        });
    }

    public function down(): void
    {
        Schema::table('zooboxi_orders', function (Blueprint $table) {
            $table->dropConstrainedForeignId('prepared_by');
            $table->dropColumn(['prepared_at', 'woo_status_synced_at']);
        });
    }
};
