<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Re-model product_registrations from ONE-ROW-PER-PRODUCT to ONE-ROW-PER-REGISTRATION.
 *
 * A product (vendor_code) has multiple SFDA registrations over time — e.g. B1104 was
 * REJECTED twice then got its certificate on the 3rd submission. The registration's
 * identity is its REFERENCE NUMBER, not the product code, so uniqueness moves to a
 * per-registration `reg_key` (reference_number, or a name-hash fallback for the few
 * rows that lack one). `item_code`/`vendor_code` are now non-unique attributes used
 * to group a product's registrations.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('product_registrations', function (Blueprint $table) {
            $table->dropUnique(['item_code']);              // product code is no longer the identity
            $table->string('reg_key')->nullable()->unique()->after('id'); // per-registration key
            $table->string('factory_name')->nullable()->after('vendor_code');
            $table->index('reference_number');
            $table->index('vendor_code');
        });
    }

    public function down(): void
    {
        Schema::table('product_registrations', function (Blueprint $table) {
            $table->dropIndex(['vendor_code']);
            $table->dropIndex(['reference_number']);
            $table->dropColumn(['factory_name']);
            $table->dropUnique(['reg_key']);
            $table->dropColumn('reg_key');
            $table->unique('item_code');
        });
    }
};
