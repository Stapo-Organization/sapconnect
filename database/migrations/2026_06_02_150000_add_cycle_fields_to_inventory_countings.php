<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->string('counting_type')->default('full')->after('status'); // 'full' | 'cycle'
            $table->date('scheduled_date')->nullable()->after('counting_type');
            $table->string('priority')->default('medium')->after('scheduled_date'); // 'high' | 'medium' | 'low'
            $table->unsignedBigInteger('cycle_plan_id')->nullable()->after('priority');
            $table->json('target_items')->nullable()->after('cycle_plan_id'); // [{item_code, abc_class}]
            $table->integer('total_target_items')->default(0)->after('target_items');
        });
    }

    public function down(): void
    {
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn([
                'counting_type',
                'scheduled_date',
                'priority',
                'cycle_plan_id',
                'target_items',
                'total_target_items',
            ]);
        });
    }
};
