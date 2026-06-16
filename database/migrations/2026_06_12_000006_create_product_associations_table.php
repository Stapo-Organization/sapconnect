<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The ONE market-basket / similarity table consumed by recommendations, bundles and
 * OOS substitutes. Directed rows (a→b) so "given item A" lookups are a single index
 * hit. rule_type=fbt is mined from C0000001 retail co-purchase (67% multi-item baskets).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_associations', function (Blueprint $table) {
            $table->id();
            $table->string('item_code_a');
            $table->string('item_code_b');
            $table->enum('rule_type', ['fbt', 'content_similar', 'substitute'])->default('fbt');
            $table->integer('co_count')->default(0);
            $table->decimal('support', 12, 8)->default(0);
            $table->decimal('confidence', 8, 6)->default(0);
            $table->decimal('lift', 12, 4)->default(0);
            $table->decimal('score', 12, 6)->default(0);
            $table->timestamp('computed_at')->nullable();

            $table->unique(['item_code_a', 'item_code_b', 'rule_type']);
            $table->index(['item_code_a', 'rule_type', 'score']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_associations');
    }
};
