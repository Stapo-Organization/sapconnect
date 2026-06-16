<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Manager-initiated decision requests raised from نبض المعرض (Showroom Pulse):
 * "اطلب تحويل" (need more of a starved hero) and "اقترح خصم" (clear trapped
 * capital). These are SUGGESTIONS for the owner — the branch manager never
 * creates a SAP transfer or sets a price directly (SAP is import-only; pricing
 * is owner-approved). The owner acts on them centrally.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('branch_action_requests', function (Blueprint $table) {
            $table->id();
            $table->enum('type', ['transfer', 'discount']);
            $table->string('item_code');
            $table->string('warehouse_code');           // the branch raising the request
            $table->unsignedBigInteger('requested_by')->nullable();
            $table->decimal('quantity', 12, 2)->nullable();   // requested units (transfer)
            $table->text('note')->nullable();
            $table->enum('status', ['pending', 'seen', 'done', 'dismissed'])->default('pending');
            $table->json('meta')->nullable();           // snapshot (lost_sales, capital_at_risk, etc.)
            $table->timestamps();

            $table->index(['warehouse_code', 'status']);
            $table->index(['type', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('branch_action_requests');
    }
};
