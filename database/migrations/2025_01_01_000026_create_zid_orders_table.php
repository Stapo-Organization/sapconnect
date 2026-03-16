<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('zid_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained('zid_stores')->cascadeOnDelete();
            $table->unsignedBigInteger('zid_order_id')->unique();
            $table->string('customer_name')->nullable();
            $table->string('order_status')->nullable();
            $table->decimal('order_total', 10, 2)->default(0);
            $table->timestamp('order_date')->nullable();
            $table->json('payload')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zid_orders');
    }
};
