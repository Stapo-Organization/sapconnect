<?php

namespace App\Services\Gamification;

use App\Models\CountingAchievement;
use App\Models\CountingScore;
use App\Models\User;

class BadgeEvaluator
{
    /**
     * Award any newly-earned badges. Returns the badges granted this call,
     * each merged with its catalogue metadata for the app to display.
     */
    public function evaluate(User $user, array $ctx): array
    {
        $earned = CountingAchievement::where('user_id', $user->id)->pluck('badge_code')->all();

        $completedTotal = CountingScore::where('user_id', $user->id)->count();
        $cycleTotal = CountingScore::where('user_id', $user->id)->where('counting_type', 'cycle')->count();
        $highAccuracy = CountingScore::where('user_id', $user->id)->where('accuracy_pct', '>=', 98)->count();

        // Quality-control counters
        $qualityTotal = CountingScore::where('user_id', $user->id)->where('category', 'quality')->count();
        $qualityWeek = CountingScore::where('user_id', $user->id)
            ->where('category', 'quality')
            ->where('on_time', true)
            ->where('completed_at', '>=', now()->subDays(7))
            ->count();

        $checks = [
            'first_count' => $completedTotal >= 1,
            'cycle_starter' => $cycleTotal >= 3,
            'cycle_champion' => $cycleTotal >= 10,
            'perfectionist' => ($ctx['accuracy_pct'] ?? 0) >= 100,
            'sharp_eye' => $highAccuracy >= 5,
            'streak_3' => ($ctx['current_streak'] ?? 0) >= 3,
            'streak_8' => ($ctx['current_streak'] ?? 0) >= 8,
            'centurion' => ($ctx['lifetime_points'] ?? 0) >= 1000,
            'first_quality' => $qualityTotal >= 1,
            'quality_pro' => $qualityTotal >= 25,
            'spotless_week' => $qualityWeek >= 5,
        ];

        $awarded = [];
        foreach ($checks as $code => $ok) {
            if ($ok && !in_array($code, $earned)) {
                CountingAchievement::firstOrCreate(
                    ['user_id' => $user->id, 'badge_code' => $code],
                    ['awarded_at' => now()]
                );
                $awarded[] = array_merge(['code' => $code], config("gamification.badges.$code", []));
            }
        }

        return $awarded;
    }
}
