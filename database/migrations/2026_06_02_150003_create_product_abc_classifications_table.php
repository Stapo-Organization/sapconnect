<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_abc_classifications', function (Blueprint $table) {
            $table->id();
            $table->string('item_code');
            $table->string('warehouse_code');
            $table->string('abc_class'); // 'A', 'B', 'C'
            $table->decimal('annual_sales_value', 15, 2)->default(0);
            $table->decimal('annual_sales_qty', 15, 4)->default(0);
            $table->decimal('current_stock', 15, 4)->default(0);
            $table->timestamp('last_counted_at')->nullable(); // Last time this item was physically counted
            $table->integer('count_in_cycle')->default(0); // Times counted in current cycle
            $table->decimal('last_variance_pct', 8, 4)->nullable(); // Last variance % for recount priority
            $table->timestamp('last_calculated_at')->nullable();
            $table->timestamps();

            $table->unique(['item_code', 'warehouse_code']);
            $table->index(['warehouse_code', 'abc_class']);
            $table->index(['warehouse_code', 'last_counted_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_abc_classifications');
    }
};
