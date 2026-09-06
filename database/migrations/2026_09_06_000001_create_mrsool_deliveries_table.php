<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Mrsool (مرسول) express last-mile ledger. Additive only.
 *
 * `mrsool_deliveries` is a permanent, append-only ledger of every courier
 * request we ever made. The row is inserted BEFORE the API call (atomic claim)
 * so a crash/duplicate click can never produce two couriers for one order:
 *   - partner_order_id is UNIQUE  → the same attempt can't be claimed twice.
 *   - mrsool_order_id  is UNIQUE  → the same remote order can't be linked twice.
 *   - at most ONE non-terminal (phase != delivered/failed) row per order is
 *     enforced in the service inside a lockForUpdate transaction.
 * An order may accumulate MANY rows over time (retries after a failed attempt),
 * hence partner_order_id gets a -R2 / -R3 … suffix per attempt.
 *
 * `mrsool_webhook_events` is a small raw-body log for debugging the unsigned
 * webhook; we never trust it beyond {id,status} and always re-fetch the order.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('mrsool_deliveries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('zooboxi_order_id')
                ->constrained('zooboxi_orders')
                ->cascadeOnDelete();
            $table->unsignedBigInteger('woo_order_id')->nullable()
                ->comment('WooCommerce order id snapshot (for the status push)');

            $table->string('partner_order_id', 60)->unique()
                ->comment('Our reference sent to Mrsool: ZB-1234, ZB-1234-R2 …');
            $table->unsignedBigInteger('mrsool_order_id')->nullable()->unique()
                ->comment('Mrsool order id (null until the create call succeeds)');
            $table->string('environment', 20)->default('staging')
                ->comment('staging | production — which Mrsool base URL created it');

            $table->string('status', 40)->nullable()
                ->comment('Raw Mrsool status string (COURIER_PENDING … DELIVERED)');
            $table->string('phase', 20)->default('searching')
                ->comment('searching | assigned | in_transit | delivered | failed');
            $table->boolean('is_partial')->default(false)
                ->comment('True when Mrsool reported PARTIALLY_DELIVERED');

            $table->decimal('price_quote', 10, 2)->nullable()
                ->comment('Quoted delivery price (SAR) at request time, if available');

            $table->string('courier_name')->nullable();
            $table->string('courier_phone', 30)->nullable();
            $table->decimal('courier_lat', 10, 7)->nullable();
            $table->decimal('courier_lng', 10, 7)->nullable();

            $table->json('events')->nullable()->comment('events_history from Mrsool');
            $table->json('pickup_images')->nullable();
            $table->json('dropoff_images')->nullable();
            $table->string('awb_url')->nullable();
            $table->text('last_error')->nullable();

            $table->foreignId('requested_by')->nullable()
                ->constrained('users')->nullOnDelete();
            $table->timestamp('requested_at')->nullable();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->timestamp('last_synced_at')->nullable();
            $table->json('raw_last')->nullable()->comment('Last full Order payload from Mrsool');

            $table->timestamps();

            $table->index('phase');
            $table->index(['zooboxi_order_id', 'phase']);
        });

        Schema::create('mrsool_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('mrsool_order_id')->nullable()->index();
            $table->string('status', 40)->nullable();
            $table->json('payload')->nullable();
            $table->boolean('processed')->default(false);
            $table->timestamp('created_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mrsool_webhook_events');
        Schema::dropIfExists('mrsool_deliveries');
    }
};
