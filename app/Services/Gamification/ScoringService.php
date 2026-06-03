<?php

namespace App\Services\Gamification;

use App\Models\CountingScore;
use App\Models\InventoryCounting;
use App\Models\User;
use App\Models\UserStreak;
use Illuminate\Support\Carbon;

class ScoringService
{
    /**
     * Award points for a completed session. Idempotent per session.
     * Returns a payload for the app's celebration overlay.
     */
    public function award(InventoryCounting $counting, array $summary, User $actingUser): array
    {
        if (CountingScore::where('inventory_counting_id', $counting->id)->exists()) {
            return ['points_earned' => 0, 'new_badges' => [], 'level_up' => false, 'new_streak' => null, 'skipped' => true];
        }

        $cfg = config('gamification');
        $p = $cfg['points'];

        // Attribute to whoever executed the cycle (cron sessions have counted_by = null).
        $userId = $counting->started_by ?? $counting->counted_by ?? $actingUser->id;
        $user = User::find($userId) ?? $actingUser;

        $isCycle = ($counting->counting_type ?? 'full') === 'cycle';

        $distinctItems = (int) $counting->lines()->distinct('item_code')->count('item_code');
        $base = $p['base_flat'] + $p['base_per_item'] * $distinctItems;

        $totalLines = $summary['total_lines'] ?? 0;
        $accurate = ($summary['match'] ?? 0) + ($summary['within_tolerance'] ?? 0);
        $accuracyPct = $totalLines > 0 ? round($accurate / $totalLines * 100, 2) : 0;
        $accuracyBonus = (int) round($base * $accuracyPct / 100);

        $completedAt = $counting->completed_at ? Carbon::parse($counting->completed_at) : now();

        $onTime = false;
        if ($isCycle && $counting->scheduled_date) {
            $due = Carbon::parse($counting->scheduled_date)->addDays($cfg['on_time_grace_days']);
            $onTime = $completedAt->lte($due);
        }
        $onTimeBonus = $onTime ? $p['on_time_bonus'] : 0;
        $cycleBonus = $isCycle ? $p['cycle_bonus'] : 0;

        $currentStreak = $this->updateStreak($user, $isCycle && $onTime, $completedAt);
        $streakBonus = $isCycle ? min($currentStreak, $p['streak_cap']) * $p['streak_step'] : 0;

        $points = $base + $accuracyBonus + $onTimeBonus + $cycleBonus + $streakBonus;

        $lifetimeBefore = (int) CountingScore::where('user_id', $user->id)->sum('points');

        CountingScore::create([
            'user_id' => $user->id,
            'inventory_counting_id' => $counting->id,
            'warehouse_code' => $counting->warehouse_code,
            'counting_type' => $counting->counting_type ?? 'full',
            'base_points' => $base,
            'accuracy_pct' => $accuracyPct,
            'on_time' => $onTime,
            'streak_bonus' => $streakBonus,
            'points' => $points,
            'completed_at' => $completedAt,
            'period_month' => $completedAt->format('Y-m'),
        ]);

        $lifetimeAfter = $lifetimeBefore + $points;
        $levelBefore = $this->levelFor($lifetimeBefore);
        $levelAfter = $this->levelFor($lifetimeAfter);

        $newBadges = (new BadgeEvaluator())->evaluate($user, [
            'accuracy_pct' => $accuracyPct,
            'current_streak' => $currentStreak,
            'lifetime_points' => $lifetimeAfter,
        ]);

        return [
            'points_earned' => $points,
            'breakdown' => [
                'base' => $base,
                'accuracy_bonus' => $accuracyBonus,
                'on_time_bonus' => $onTimeBonus,
                'cycle_bonus' => $cycleBonus,
                'streak_bonus' => $streakBonus,
            ],
            'new_badges' => $newBadges,
            'level_up' => $levelAfter > $levelBefore,
            'level' => $levelAfter,
            'new_streak' => $currentStreak,
        ];
    }

    /**
     * Advance the consecutive-week streak when a cycle was completed on time.
     */
    protected function updateStreak(User $user, bool $advances, Carbon $completedAt): int
    {
        $streak = UserStreak::firstOrNew(['user_id' => $user->id]);

        if (!$advances) {
            return $streak->current_streak ?? 0;
        }

        $weekStart = $completedAt->copy()->startOfWeek(Carbon::MONDAY)->toDateString();
        $prevWeek = $completedAt->copy()->startOfWeek(Carbon::MONDAY)->subWeek()->toDateString();
        $last = $streak->last_cycle_week_completed
            ? Carbon::parse($streak->last_cycle_week_completed)->toDateString()
            : null;

        if ($last === $weekStart) {
            // already counted this week — no change
        } elseif ($last === $prevWeek) {
            $streak->current_streak = ($streak->current_streak ?? 0) + 1;
        } else {
            $streak->current_streak = 1;
        }

        $streak->last_cycle_week_completed = $weekStart;
        $streak->longest_streak = max($streak->longest_streak ?? 0, $streak->current_streak);
        $streak->save();

        return $streak->current_streak;
    }

    public function levelFor(int $points): int
    {
        $level = 1;
        foreach (config('gamification.levels') as $i => $threshold) {
            if ($points >= $threshold) {
                $level = $i + 1;
            }
        }
        return $level;
    }
}
