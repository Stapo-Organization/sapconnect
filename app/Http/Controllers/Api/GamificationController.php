<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CountingAchievement;
use App\Models\CountingScore;
use App\Models\User;
use App\Models\UserStreak;
use App\Services\Gamification\ScoringService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class GamificationController extends Controller
{
    /**
     * The authenticated user's gamification profile: points, level, streak,
     * accuracy, weekly goal, recent badges and rank summary.
     */
    public function me(Request $request)
    {
        $user = $request->user();
        $scoring = new ScoringService();
        $month = now()->format('Y-m');

        $lifetime = (int) CountingScore::where('user_id', $user->id)->sum('points');
        $monthPoints = (int) CountingScore::where('user_id', $user->id)->where('period_month', $month)->sum('points');
        $accuracyAvg = round((float) CountingScore::where('user_id', $user->id)->avg('accuracy_pct'), 1);

        $level = $scoring->levelFor($lifetime);
        $levels = config('gamification.levels');
        $labels = config('gamification.level_labels');
        $curThreshold = $levels[$level - 1] ?? 0;
        $nextThreshold = $levels[$level] ?? null;

        $streak = UserStreak::find($user->id);

        $fullCount = CountingScore::where('user_id', $user->id)->where('counting_type', 'full')->count();
        $cycleCount = CountingScore::where('user_id', $user->id)->where('counting_type', 'cycle')->count();

        $weekStart = now()->startOfWeek(Carbon::MONDAY);
        $completedCyclesThisWeek = CountingScore::where('user_id', $user->id)
            ->where('counting_type', 'cycle')
            ->where('completed_at', '>=', $weekStart)
            ->count();

        $recentBadges = CountingAchievement::where('user_id', $user->id)
            ->orderByDesc('awarded_at')->limit(5)->get()
            ->map(fn($b) => array_merge(['code' => $b->badge_code], config("gamification.badges.$b->badge_code", [])));

        // Ranks
        $codes = $this->userWarehouseCodes($user);
        $primaryWh = $codes[0] ?? null;

        $companyList = $this->rankList($month);
        $branchList = $primaryWh ? $this->rankList($month, $primaryWh) : collect();
        $branchTotals = $this->branchTotals($month);

        return response()->json([
            'points_total' => $lifetime,
            'points_month' => $monthPoints,
            'level' => $level,
            'level_label' => $labels[$level - 1] ?? "Lvl $level",
            'points_into_level' => $lifetime - $curThreshold,
            'points_to_next' => $nextThreshold !== null ? max(0, $nextThreshold - $lifetime) : null,
            'next_level_span' => $nextThreshold !== null ? $nextThreshold - $curThreshold : null,
            'streak' => [
                'current' => $streak->current_streak ?? 0,
                'longest' => $streak->longest_streak ?? 0,
            ],
            'accuracy_avg' => $accuracyAvg,
            'counts' => ['full' => $fullCount, 'cycle' => $cycleCount],
            'weekly_goal' => [
                'target' => config('gamification.weekly_goal'),
                'completed' => $completedCyclesThisWeek,
            ],
            'rank' => [
                'branch' => [
                    'warehouse_code' => $primaryWh,
                    'position' => $primaryWh ? $this->branchPosition($branchTotals, $primaryWh) : null,
                    'total' => $branchTotals->count(),
                ],
                'within_branch' => [
                    'position' => $this->positionOf($branchList, $user->id),
                    'total' => $branchList->count(),
                    'named' => true,
                ],
                'company' => [
                    'position' => $this->positionOf($companyList, $user->id),
                    'total' => $companyList->count(),
                    'named' => false,
                ],
            ],
            'recent_badges' => $recentBadges,
        ]);
    }

    /**
     * Full badge catalogue with earned state.
     */
    public function badges(Request $request)
    {
        $user = $request->user();
        $earned = CountingAchievement::where('user_id', $user->id)
            ->get()->keyBy('badge_code');

        $catalogue = collect(config('gamification.badges'))->map(function ($meta, $code) use ($earned) {
            return array_merge(['code' => $code], $meta, [
                'earned' => $earned->has($code),
                'awarded_at' => $earned->get($code)?->awarded_at,
            ]);
        })->values();

        return response()->json(['badges' => $catalogue]);
    }

    /**
     * Leaderboard. type=branches|employees, period=month (YYYY-MM) or 'month'.
     * - branches: all branches, named, visible to everyone.
     * - employees: admin sees all named; a manager sees own-branch rows named
     *   plus an anonymized company standing.
     */
    public function leaderboard(Request $request)
    {
        $user = $request->user();
        $type = $request->get('type', 'branches');
        $month = $request->get('period');
        if (!$month || $month === 'month') {
            $month = now()->format('Y-m');
        }

        if ($type === 'branches') {
            $totals = $this->branchTotals($month);
            $names = \App\Models\Warehouse::whereIn('warehouse_code', $totals->pluck('warehouse_code'))
                ->pluck('warehouse_name', 'warehouse_code');
            $myCodes = $this->userWarehouseCodes($user);
            $rows = $totals->values()->map(fn($r, $i) => [
                'position' => $i + 1,
                'warehouse_code' => $r->warehouse_code,
                'name' => $names[$r->warehouse_code] ?? $r->warehouse_code,
                'points' => (int) $r->pts,
                'is_me' => in_array($r->warehouse_code, $myCodes),
            ]);
            return response()->json(['period' => $month, 'type' => 'branches', 'rows' => $rows]);
        }

        // employees
        $isAdmin = $user->hasAnyRole(['Super Admin', 'Stakeholder']);
        $scoring = new ScoringService();

        if ($isAdmin) {
            $list = $this->rankList($month);
            $rows = $this->decorateUsers($list, $user->id, $scoring, named: true);
            return response()->json([
                'period' => $month, 'type' => 'employees', 'scope' => 'company', 'named' => true, 'rows' => $rows,
            ]);
        }

        // Manager: own-branch named + anonymized company position
        $codes = $this->userWarehouseCodes($user);
        $primaryWh = $codes[0] ?? null;
        $branchList = $primaryWh ? $this->rankList($month, $primaryWh) : collect();
        $rows = $this->decorateUsers($branchList, $user->id, $scoring, named: true);

        $companyList = $this->rankList($month);
        return response()->json([
            'period' => $month,
            'type' => 'employees',
            'scope' => 'branch',
            'named' => true,
            'rows' => $rows,
            'company' => [
                'position' => $this->positionOf($companyList, $user->id),
                'total' => $companyList->count(),
            ],
        ]);
    }

    // ─── Helpers ────────────────────────────────────────────────

    private function userWarehouseCodes($user): array
    {
        $codes = $user->warehouse_code;
        if (is_string($codes)) {
            $decoded = json_decode($codes, true);
            $codes = (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) ? $decoded : [$codes];
        }
        return is_array($codes) ? array_values($codes) : ($codes ? [$codes] : []);
    }

    private function rankList(string $month, ?string $warehouse = null)
    {
        $q = CountingScore::where('period_month', $month);
        if ($warehouse) {
            $q->where('warehouse_code', $warehouse);
        }
        return $q->select('user_id', DB::raw('SUM(points) as pts'))
            ->groupBy('user_id')->orderByDesc('pts')->get();
    }

    private function branchTotals(string $month)
    {
        return CountingScore::where('period_month', $month)
            ->whereNotNull('warehouse_code')
            ->select('warehouse_code', DB::raw('SUM(points) as pts'))
            ->groupBy('warehouse_code')->orderByDesc('pts')->get();
    }

    private function positionOf($list, $userId): ?int
    {
        $idx = $list->search(fn($r) => (int) $r->user_id === (int) $userId);
        return $idx === false ? null : $idx + 1;
    }

    private function branchPosition($totals, string $warehouse): ?int
    {
        $idx = $totals->search(fn($r) => $r->warehouse_code === $warehouse);
        return $idx === false ? null : $idx + 1;
    }

    private function decorateUsers($list, $meId, ScoringService $scoring, bool $named): array
    {
        $users = User::whereIn('id', $list->pluck('user_id'))->get()->keyBy('id');
        return $list->values()->map(function ($r, $i) use ($users, $meId, $scoring, $named) {
            $lifetime = (int) CountingScore::where('user_id', $r->user_id)->sum('points');
            return [
                'position' => $i + 1,
                'user_id' => $named ? $r->user_id : null,
                'name' => $named ? ($users[$r->user_id]->name ?? '—') : null,
                'points' => (int) $r->pts,
                'level' => $scoring->levelFor($lifetime),
                'is_me' => (int) $r->user_id === (int) $meId,
            ];
        })->toArray();
    }
}
