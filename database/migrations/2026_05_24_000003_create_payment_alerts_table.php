<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Stores financial alerts triggered by the ShipmentObserver when
     * shipment status changes match payment policy conditions.
     */
    public function up(): void
    {
        Schema::create('payment_alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained()->cascadeOnDelete();
            $table->foreignId('purchase_order_id')->constrained()->cascadeOnDelete();
            $table->foreignId('payment_policy_line_id')->constrained()->cascadeOnDelete();
            $table->decimal('due_amount', 15, 2);
            $table->date('due_date');
            $table->string('status')->default('pending'); // pending, paid, overdue
            $table->text('notes')->nullable();
            $table->foreignId('marked_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_alerts');
    }
};
