<?php

namespace App\Services\Gamification;

use App\Models\CountingScore;
use App\Models\QualityTaskInstance;
use App\Models\User;
use Illuminate\Support\Carbon;

class QualityScoringService
{
    /**
     * Award points for a submitted quality task. Idempotent per instance.
     * Points land in the SAME counting_scores pool so they count toward the
     * existing level / leaderboard. Returns the celebration payload.
     */
    public function award(QualityTaskInstance $instance, User $actingUser): array
    {
        if (CountingScore::where('quality_task_instance_id', $instance->id)->exists()) {
            return ['points_earned' => 0, 'new_badges' => [], 'level_up' => false, 'new_streak' => null, 'skipped' => true];
        }

        $cfg = config('gamification');
        $q = $cfg['quality'];

        $user = ($instance->submitted_by ? User::find($instance->submitted_by) : null) ?? $actingUser;

        $submittedAt = $instance->submitted_at ? Carbon::parse($instance->submitted_at) : now();

        // On time = submitted on/before the scheduled date + grace.
        $onTime = false;
        if ($instance->scheduled_date) {
            $due = Carbon::parse($instance->scheduled_date)->endOfDay()->addDays($cfg['on_time_grace_days']);
            $onTime = $submittedAt->lte($due);
        }

        $base = $q['base'];
        $onTimeBonus = $onTime ? $q['on_time_bonus'] : 0;
        // Photo/checklist proof earns a completeness bonus; acknowledge-only does not.
        $proofType = $instance->proofType();
        $completenessBonus = in_array($proofType, ['photo', 'checklist'], true) ? $q['completeness_bonus'] : 0;

        $points = $base + $onTimeBonus + $completenessBonus;

        $lifetimeBefore = (int) CountingScore::where('user_id', $user->id)->sum('points');

        CountingScore::create([
            'user_id' => $user->id,
            'inventory_counting_id' => null,
            'quality_task_instance_id' => $instance->id,
            'warehouse_code' => $instance->warehouse_code,
            'counting_type' => 'quality',
            'category' => 'quality',
            'base_points' => $base,
            'accuracy_pct' => 0,
            'on_time' => $onTime,
            'streak_bonus' => 0,
            'points' => $points,
            'completed_at' => $submittedAt,
            'period_month' => $submittedAt->format('Y-m'),
        ]);

        $lifetimeAfter = $lifetimeBefore + $points;
        $levelService = new ScoringService();
        $levelBefore = $levelService->levelFor($lifetimeBefore);
        $levelAfter = $levelService->levelFor($lifetimeAfter);

        $newBadges = (new BadgeEvaluator())->evaluate($user, [
            'lifetime_points' => $lifetimeAfter,
        ]);

        return [
            'points_earned' => $points,
            'breakdown' => [
                'base' => $base,
                'on_time_bonus' => $onTimeBonus,
                'completeness_bonus' => $completenessBonus,
            ],
            'new_badges' => $newBadges,
            'level_up' => $levelAfter > $levelBefore,
            'level' => $levelAfter,
            'new_streak' => null,
        ];
    }
}
