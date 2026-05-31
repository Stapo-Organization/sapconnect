<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Zooboxi orders tracking tables.
     * Stores WooCommerce orders with delivery type, warehouse assignment,
     * and SAP invoice sync status.
     */
    public function up(): void
    {
        Schema::create('zooboxi_orders', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('woo_order_id')->unique()
                ->comment('WooCommerce order ID');
            $table->string('woo_order_number', 50)->nullable()
                ->comment('Human-readable order number (e.g., ZB-1234)');
            $table->string('warehouse_code')->nullable()
                ->comment('Warehouse responsible for fulfillment');
            $table->enum('delivery_type', ['express', 'same_day', 'shipping', 'pickup'])
                ->default('shipping')
                ->comment('Delivery tier based on customer location');
            $table->enum('delivery_status', [
                'pending',
                'preparing',
                'ready_for_pickup',
                'out_for_delivery',
                'delivered',
                'cancelled',
            ])->default('pending');
            $table->decimal('customer_latitude', 10, 8)->nullable();
            $table->decimal('customer_longitude', 11, 8)->nullable();
            $table->string('customer_city', 100)->nullable();
            $table->string('customer_name')->nullable();
            $table->string('customer_phone', 20)->nullable();
            $table->string('customer_email')->nullable();
            $table->text('customer_address')->nullable();
            $table->string('sap_doc_entry', 50)->nullable()
                ->comment('SAP invoice document entry number');
            $table->timestamp('sap_synced_at')->nullable()
                ->comment('When the order was synced to SAP');
            $table->string('payment_method', 50)->nullable();
            $table->enum('payment_status', ['pending', 'paid', 'refunded', 'failed'])
                ->default('pending');
            $table->decimal('subtotal', 12, 2)->default(0);
            $table->decimal('delivery_fee', 10, 2)->default(0);
            $table->decimal('tax_amount', 10, 2)->default(0);
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->text('notes')->nullable();
            $table->timestamps();

            // Indexes
            $table->index('warehouse_code');
            $table->index('delivery_status');
            $table->index('created_at');
        });

        Schema::create('zooboxi_order_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('zooboxi_order_id')
                ->constrained('zooboxi_orders')
                ->cascadeOnDelete();
            $table->string('item_code')
                ->comment('Product SKU from SAP');
            $table->string('item_name')->nullable()
                ->comment('Product name snapshot');
            $table->string('warehouse_code')
                ->comment('Warehouse the stock is deducted from');
            $table->decimal('quantity', 10, 2);
            $table->decimal('unit_price', 10, 2);
            $table->decimal('total_price', 12, 2);
            $table->timestamps();

            $table->index('item_code');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('zooboxi_order_lines');
        Schema::dropIfExists('zooboxi_orders');
    }
};
