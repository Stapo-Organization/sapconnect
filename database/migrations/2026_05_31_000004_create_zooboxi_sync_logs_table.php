<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Zooboxi sync log table.
     * Tracks every sync operation between sapconnect and WooCommerce
     * for monitoring, debugging, and the admin dashboard.
     */
    public function up(): void
    {
        Schema::create('zooboxi_sync_logs', function (Blueprint $table) {
            $table->id();
            $table->enum('sync_type', ['products', 'stock', 'prices', 'orders'])
                ->comment('What is being synced');
            $table->enum('direction', ['pull', 'push'])->default('pull')
                ->comment('pull = from WooCommerce, push = to WooCommerce');
            $table->enum('status', ['running', 'completed', 'failed'])->default('running');
            $table->unsignedInteger('records_total')->default(0)
                ->comment('Total records to process');
            $table->unsignedInteger('records_synced')->default(0)
                ->comment('Successfully synced records');
            $table->unsignedInteger('records_failed')->default(0)
                ->comment('Failed records');
            $table->text('error_message')->nullable()
                ->comment('Error details if status = failed');
            $table->json('details')->nullable()
                ->comment('Additional sync metadata (e.g., affected SKUs)');
            $table->timestamp('started_at')->useCurrent();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            // Index for dashboard queries
            $table->index(['sync_type', 'status', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('zooboxi_sync_logs');
    }
};
