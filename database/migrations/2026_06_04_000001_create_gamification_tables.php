<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One immutable row per completed session (auditable points).
        Schema::create('counting_scores', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedBigInteger('inventory_counting_id')->nullable()->unique();
            $table->string('warehouse_code')->nullable();
            $table->string('counting_type')->default('full');
            $table->integer('base_points')->default(0);
            $table->decimal('accuracy_pct', 5, 2)->default(0);
            $table->boolean('on_time')->default(false);
            $table->integer('streak_bonus')->default(0);
            $table->integer('points')->default(0);
            $table->timestamp('completed_at')->nullable();
            $table->string('period_month', 7)->index(); // YYYY-MM
            $table->timestamps();

            $table->index(['user_id', 'period_month']);
            $table->foreign('inventory_counting_id')->references('id')->on('inventory_countings')->nullOnDelete();
        });

        // Earned badges (one per code per user).
        Schema::create('counting_achievements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('badge_code');
            $table->timestamp('awarded_at')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'badge_code']);
        });

        // Consecutive-week streaks per user.
        Schema::create('user_streaks', function (Blueprint $table) {
            $table->foreignId('user_id')->primary()->constrained('users')->cascadeOnDelete();
            $table->integer('current_streak')->default(0);
            $table->integer('longest_streak')->default(0);
            $table->date('last_cycle_week_completed')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('counting_scores');
        Schema::dropIfExists('counting_achievements');
        Schema::dropIfExists('user_streaks');
    }
};
