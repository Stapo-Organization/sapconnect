<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * SFDA product-registration tracking — replaces the manual "Registration Tracking",
 * "Saud", "Sheet12/14/15" tabs of the Operations workbook.
 *
 * DELIBERATELY STANDALONE. Registration keys off LEGACY vendor codes (USA-868,
 * AH-4037, B1104) that do NOT match SAP item codes (P12300110…) — verified against
 * live SAP: 0 matches on ItemCode / ForeignName / BarCode / SupplierCatalogNo, and
 * names differ textually too. So there is NO hard FK to products/brands: we store
 * the code + name + brand as self-sufficient snapshots and resolve a nullable
 * `product_id`/`brand_id` opportunistically (best-effort, human-confirmed later).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_registrations', function (Blueprint $table) {
            $table->id();

            // Canonical dedup key = the (legacy) item/vendor code from the sheets.
            $table->string('item_code')->unique();

            // Best-effort resolved links — nullable, NO foreign-key constraint
            // (products.item_code is only unique per source; brands table swaps by env).
            $table->unsignedBigInteger('product_id')->nullable()->index();
            $table->string('brand_code')->nullable()->index();
            $table->unsignedBigInteger('brand_id')->nullable();

            // Self-sufficient snapshots (so a row is useful even when product_id is null).
            $table->string('item_name')->nullable();          // EN name snapshot
            $table->string('name_ar')->nullable();            // Arabic name snapshot
            $table->string('range')->nullable();              // product family / sub-brand
            $table->string('vendor_code')->nullable();

            // Regulatory identifiers — stored RAW (formats drift year to year).
            $table->string('reference_number')->nullable();   // submission/ref no. (2024-312651, P-1-N-…)
            $table->string('certificate_number')->nullable(); // MAFE… / FEM-25-…

            // Canonical status key (see ProductRegistration::statusOptions()).
            $table->string('status')->default('new')->index();
            $table->boolean('is_registered')->default(false);

            $table->date('request_date')->nullable();
            $table->date('received_date')->nullable();
            $table->date('expiry_date')->nullable()->index();

            $table->text('remarks')->nullable();
            $table->string('source_sheet')->nullable();       // provenance of the winning row

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_registrations');
    }
};
