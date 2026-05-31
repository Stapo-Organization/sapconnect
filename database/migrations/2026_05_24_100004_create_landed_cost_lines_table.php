<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('landed_cost_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('landed_cost_id')->constrained()->cascadeOnDelete();
            $table->foreignId('purchase_order_line_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();
            $table->string('country_of_origin')->nullable();
            $table->integer('quantity')->default(0);
            $table->decimal('unit_price_foreign', 15, 4)->default(0)->comment('Supplier currency unit price');
            $table->decimal('total_value_foreign', 15, 2)->default(0)->comment('qty × unit_price (auto)');
            $table->decimal('value_participate_pct', 8, 6)->default(0)->comment('This line value / total (auto)');
            $table->decimal('shipping_per_unit', 15, 4)->default(0)->comment('Allocated shipping per unit (auto)');
            $table->decimal('total_per_unit_foreign', 15, 4)->default(0)->comment('unit_price + shipping (auto)');
            $table->decimal('unit_cost_sar', 15, 4)->default(0)->comment('Foreign cost × exchange_rate (auto)');
            $table->decimal('unit_cost_sar_with_vat', 15, 4)->default(0)->comment('SAR cost × (1+VAT) (auto)');
            $table->decimal('po_unit_price', 15, 4)->default(0)->comment('PO purchase price per unit');
            $table->decimal('po_unit_price_with_vat', 15, 4)->default(0);
            $table->decimal('wholesale_price_with_vat', 15, 4)->default(0)->comment('Suggested wholesale with VAT (manual)');
            $table->decimal('wholesale_price', 15, 4)->default(0)->comment('Suggested wholesale without VAT (manual)');
            $table->decimal('gross_profit_pct', 8, 4)->default(0)->comment('GP% (auto)');
            $table->decimal('profit_per_unit_sar', 15, 4)->default(0)->comment('Profit SAR/unit (auto)');
            $table->decimal('old_sales_price', 15, 4)->default(0)->comment('Previous sales price (manual)');
            $table->decimal('new_price', 15, 4)->default(0)->comment('New sales price (manual)');
            $table->decimal('total_net_weight', 15, 4)->default(0);
            $table->string('remark')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('landed_cost_lines');
    }
};
