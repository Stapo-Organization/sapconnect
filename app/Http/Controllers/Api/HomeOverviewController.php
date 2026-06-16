<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InventoryCounting;
use App\Models\QualityTaskInstance;
use App\Models\StockTransfer;
use App\Models\ZooboxiOrder;
use App\Services\Home\HomeFeedBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Single aggregation endpoint behind the smart home dashboard.
 *
 * Replaces the home screen's previous 6 sequential round-trips with ONE call.
 * It reuses the existing per-feature summary endpoints verbatim (so module
 * payloads stay byte-identical and the app keeps its current parsers), then
 * folds every actionable item into a server-scored priority feed via
 * HomeFeedBuilder. Read-only; never writes to SAP or anything else.
 */
class HomeOverviewController extends Controller
{
    public function index(Request $request, HomeFeedBuilder $builder): JsonResponse
    {
        $user = $request->user();
        $isOwner = (bool) ($user && $user->hasRole('Super Admin'));

        // Reuse the existing summary endpoints — identical serialization.
        $zooboxi = app(ZooboxiOrderController::class)->summary($request)->getData(true);
        $quality = app(QualityTaskController::class)->summary($request)->getData(true);
        $counting = app(InventoryCountingController::class)->schedule($request)->getData(true);
        $gamification = app(GamificationController::class)->me($request)->getData(true);
        $transfers = $this->transferStats($user);
        $promotions = $isOwner
            ? app(PromotionController::class)->summary($request)->getData(true)
            : null;

        $modules = [
            'zooboxi' => $zooboxi,
            'quality' => $quality,
            'counting' => $counting,
            'transfers' => $transfers,
            'promotions' => $promotions,
            'gamification' => $gamification,
        ];

        // One warehouse → the branch name is redundant on every feed item.
        $singleBranch = count($this->warehouseCodes($user)) <= 1;

        $built = $builder->build($modules, $isOwner, $singleBranch);

        return response()->json([
            'generated_at' => now()->toIso8601String(),
            'is_owner' => $isOwner,
            'greeting_period' => $this->greetingPeriod(),
            'feed' => $built['feed'],
            'your_day' => $this->yourDay($user, $gamification),
            'progress' => $this->progress($gamification),
            'module_order' => $built['module_order'],
            'modules' => $modules,
        ]);
    }

    /**
     * GET /dashboard-stats — kept for back-compat; delegates to the shared
     * transfer/counting stat helper so there is one source of truth.
     */
    public function dashboardStats(Request $request): JsonResponse
    {
        return response()->json($this->transferStats($request->user()));
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Pending transfer + in-progress counting counts for the user's warehouses.
     * (Body lifted from the former /dashboard-stats closure.)
     */
    private function transferStats($user): array
    {
        $codes = $this->warehouseCodes($user);

        $pendingSend = StockTransfer::where('internal_status', 'New')
            ->whereIn('from_warehouse', $codes)
            ->count();

        $pendingReceive = StockTransfer::where('internal_status', 'Shipped')
            ->whereIn('to_warehouse', $codes)
            ->count();

        $inProgressCounting = InventoryCounting::where('status', 'in_progress')
            ->where(function ($q) use ($user, $codes) {
                $q->where('counted_by', $user->name)
                  ->orWhereIn('warehouse_code', $codes);
            })
            ->count();

        return [
            'pending_send' => $pendingSend,
            'pending_receive' => $pendingReceive,
            'in_progress_counting' => $inProgressCounting,
        ];
    }

    /**
     * "Your day" mini-summary — work the user closed out today + streak.
     */
    private function yourDay($user, array $gamification): array
    {
        $today = now()->startOfDay();

        $ordersFulfilled = ZooboxiOrder::where('prepared_by', $user->id)
            ->where('prepared_at', '>=', $today)
            ->count();

        $qualityDone = QualityTaskInstance::where('submitted_by', $user->id)
            ->where('submitted_at', '>=', $today)
            ->count();

        $countsDone = InventoryCounting::where('status', 'completed')
            ->where('counted_by', $user->id)
            ->where('completed_at', '>=', $today)
            ->count();

        return [
            'orders_fulfilled_today' => $ordersFulfilled,
            'tasks_done_today' => $qualityDone + $countsDone,
            'streak' => (int) ($gamification['streak']['current'] ?? 0),
        ];
    }

    /**
     * Daily progress ring — weekly cycle-count goal from gamification.
     */
    private function progress(array $gamification): array
    {
        $target = (int) ($gamification['weekly_goal']['target'] ?? 0);
        $current = (int) ($gamification['weekly_goal']['completed'] ?? 0);
        $percent = $target > 0 ? (int) round(min(100, $current / $target * 100)) : 0;

        return [
            'kind' => 'weekly_goal',
            'percent' => $percent,
            'label' => 'الهدف الأسبوعي',
            'current' => $current,
            'target' => $target,
        ];
    }

    private function greetingPeriod(): string
    {
        $hour = (int) now()->format('G');
        if ($hour < 12) {
            return 'morning';
        }
        if ($hour < 17) {
            return 'afternoon';
        }
        return 'evening';
    }

    /** Decode the user's warehouse codes (JSON array or scalar). */
    private function warehouseCodes($user): array
    {
        if (!$user || !$user->warehouse_code) {
            return [];
        }
        $codes = $user->warehouse_code;
        if (is_string($codes)) {
            $decoded = json_decode($codes, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $codes = $decoded;
            }
        }
        return is_array($codes) ? $codes : [$codes];
    }
}
