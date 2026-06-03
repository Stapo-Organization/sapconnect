<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Let quality-task completions land in the SAME points pool so the
        // existing me()/leaderboard()/badges() (SUM over counting_scores) include them.
        Schema::table('counting_scores', function (Blueprint $table) {
            $table->string('category')->default('counting')->after('counting_type'); // counting | quality
            $table->unsignedBigInteger('quality_task_instance_id')->nullable()->after('inventory_counting_id');

            $table->index('category');
            $table->unique('quality_task_instance_id');
            $table->foreign('quality_task_instance_id')->references('id')->on('quality_task_instances')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('counting_scores', function (Blueprint $table) {
            $table->dropForeign(['quality_task_instance_id']);
            $table->dropUnique(['quality_task_instance_id']);
            $table->dropIndex(['category']);
            $table->dropColumn(['category', 'quality_task_instance_id']);
        });
    }
};
