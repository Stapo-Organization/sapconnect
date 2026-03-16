<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('stock_transfer_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('stock_transfer_id')->constrained('sap_stock_transfers')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('action'); // 'imported', 'items_sent', 'send_confirmed', 'items_received', 'receive_confirmed'
            $table->string('from_status')->nullable();
            $table->string('to_status')->nullable();
            $table->json('payload')->nullable(); // Additional details (quantities, notes, etc.)
            $table->string('ip_address')->nullable();
            $table->timestamps();

            $table->index(['stock_transfer_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_transfer_logs');
    }
};
