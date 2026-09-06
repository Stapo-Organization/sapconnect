<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Owner-approved sellable bundles («حزم زوبوكسي»), cloned from the Mowkly
 * playbook and generated nightly from the existing intelligence. A bundle is
 * a SUGGESTION until the owner approves it in the app; the store then
 * materialises it as a real WC product whose per-warehouse stock is the min
 * over its components — so the fulfillment resolver works on it unchanged.
 *
 * Channel safety: the bundle price hides every unit price (nothing shows a
 * discounted shelf price), and the generator's guard keeps the price above
 * Σcost*1.10 and the savings under the owner's caps (25% healthy / 40% gift).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_bundles', function (Blueprint $table) {
            $table->id();
            $table->string('bundle_key')->unique();   // dedup: template+members hash
            $table->string('template');               // stacking|variety|companion|smart_gift|seasonal
            $table->string('status')->default('suggested'); // suggested|approved|live|retired|rejected

            // Arabic storefront copy (owner-editable at approval)
            $table->string('name_ar');
            $table->string('subtitle_ar')->nullable();
            $table->string('free_label')->nullable(); // "10 + 3" — the Mowkly headline math

            $table->string('anchor_item_code')->nullable();
            $table->string('species')->default('mixed'); // cat|dog|bird|small_pet|mixed
            $table->string('kind')->nullable();           // wet|dry|litter|treat|mixed

            // Money (snapshot at suggestion; re-guarded at approval)
            $table->decimal('sum_retail', 15, 4)->default(0);   // Σ components at retail
            $table->decimal('bundle_price', 15, 4)->default(0); // what the customer pays
            $table->decimal('sum_cost', 15, 4)->default(0);
            $table->decimal('floor_price', 15, 4)->default(0);  // Σcost*1.10
            $table->decimal('savings_pct', 5, 2)->default(0);

            // Stock awareness
            $table->string('stock_class')->default('central');  // express|central
            $table->json('warehouse_scope')->nullable();        // warehouses that can build ≥K bundles

            // Why suggested
            $table->decimal('score', 12, 3)->default(0);
            $table->json('rationale')->nullable();

            // Store materialisation
            $table->unsignedBigInteger('wc_product_id')->nullable();
            $table->string('image_url')->nullable();

            // Lifecycle audit
            $table->unsignedBigInteger('approved_by')->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->string('rejected_reason')->nullable();
            $table->timestamp('retired_at')->nullable();
            $table->timestamp('computed_at')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index(['status', 'template']);
            $table->index('anchor_item_code');
        });

        Schema::create('product_bundle_items', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('product_bundle_id');
            $table->string('item_code');
            $table->string('item_name')->nullable();
            $table->string('barcode')->nullable();     // store SKU — what order lines carry
            $table->unsignedInteger('qty')->default(1);
            $table->string('role')->default('member'); // anchor|member|gift
            $table->decimal('unit_retail', 15, 4)->default(0);
            $table->decimal('unit_cost', 15, 4)->default(0);
            $table->timestamps();

            $table->index('product_bundle_id');
            $table->index('item_code');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_bundle_items');
        Schema::dropIfExists('product_bundles');
    }
};
