<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('sap_stock_transfer_shipments', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('stock_transfer_id');
            $table->string('tracking_number')->nullable();
            $table->boolean('is_received')->default(false);
            $table->timestamp('received_at')->nullable();
            $table->timestamps();

            $table->foreign('stock_transfer_id')
                ->references('id')
                ->on('sap_stock_transfers')
                ->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sap_stock_transfer_shipments');
    }
};
