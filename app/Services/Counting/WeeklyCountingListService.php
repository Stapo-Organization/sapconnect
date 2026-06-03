<?php

namespace App\Services\Counting;

use App\Models\InventoryCounting;
use App\Models\InventoryCyclePlan;
use App\Models\ProductAbcClassification;
use App\Models\Warehouse;

class WeeklyCountingListService
{
    /**
     * Generate a weekly counting list for a cycle plan.
     *
     * Logic:
     * 1. Get ABC item counts for the plan's warehouse
     * 2. Calculate weekly quotas based on plan's frequencies and weekly_cap
     * 3. Select items per class, prioritizing:
     *    a. Never counted (last_counted_at IS NULL)
     *    b. High variance items (|last_variance_pct| DESC)
     *    c. Oldest counted (last_counted_at ASC)
     * 4. Create an InventoryCounting session with type='cycle' and target_items
     *
     * @return InventoryCounting|null  The created session, or null if no items to count
     */
    public function generateForPlan(InventoryCyclePlan $plan): ?InventoryCounting
    {
        $warehouseCode = $plan->warehouse_code;

        // Get ABC item counts
        $countA = ProductAbcClassification::forWarehouse($warehouseCode)->classA()->count();
        $countB = ProductAbcClassification::forWarehouse($warehouseCode)->classB()->count();
        $countC = ProductAbcClassification::forWarehouse($warehouseCode)->classC()->count();

        if ($countA + $countB + $countC === 0) {
            return null; // No classified items
        }

        // Calculate quotas
        $quotas = $plan->calculateWeeklyQuotas($countA, $countB, $countC);

        // Select items per class
        $targetItems = [];

        foreach (['A', 'B', 'C'] as $class) {
            $quota = $quotas[$class] ?? 0;
            if ($quota <= 0) continue;

            $items = ProductAbcClassification::forWarehouse($warehouseCode)
                ->where('abc_class', $class)
                ->needsCounting()
                ->limit($quota)
                ->get();

            foreach ($items as $item) {
                $targetItems[] = [
                    'item_code' => $item->item_code,
                    'abc_class' => $class,
                ];
            }
        }

        if (empty($targetItems)) {
            return null;
        }

        // Determine priority based on whether there are overdue items
        $hasNeverCounted = collect($targetItems)->filter(function ($item) use ($warehouseCode) {
            $abc = ProductAbcClassification::where('item_code', $item['item_code'])
                ->where('warehouse_code', $warehouseCode)
                ->first();
            return $abc && $abc->last_counted_at === null;
        })->count();

        $priority = $hasNeverCounted > ($quotas['total'] / 2) ? 'high' : 'medium';

        // Get warehouse name
        $warehouse = Warehouse::where('warehouse_code', $warehouseCode)->first();

        // Create the counting session
        $counting = InventoryCounting::create([
            'warehouse_code' => $warehouseCode,
            'warehouse_name' => $warehouse?->warehouse_name,
            'status' => InventoryCounting::STATUS_IN_PROGRESS,
            'counting_type' => InventoryCounting::TYPE_CYCLE,
            'scheduled_date' => now()->toDateString(),
            'priority' => $priority,
            'cycle_plan_id' => $plan->id,
            'target_items' => $targetItems,
            'total_target_items' => count($targetItems),
            'notes' => "جرد دوري أسبوعي — {$plan->plan_name} (الأسبوع {$plan->current_week_number})",
        ]);

        // Notify the warehouse's managers that a new cycle task is ready (push only).
        try {
            (new \App\Services\NotificationService())->pushToWarehouseUsers(
                $warehouseCode,
                'مهمة جرد دوري جديدة',
                "جرد هذا الأسبوع جاهز — {$counting->total_target_items} صنف في " . ($warehouse?->warehouse_name ?? $warehouseCode),
                ['type' => 'cycle_due', 'session_id' => $counting->id, 'warehouse_code' => $warehouseCode]
            );
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Cycle generation push failed: ' . $e->getMessage());
        }

        // Update plan tracking
        $plan->update([
            'last_generated_at' => now(),
            'current_week_number' => $plan->current_week_number + 1,
            'next_due_date' => now()->addDays(7)->toDateString(),
        ]);

        // If cycle is complete, reset
        if ($plan->current_week_number >= $plan->cycle_length_weeks) {
            $this->resetCycle($plan);
        }

        return $counting;
    }

    /**
     * Check all active plans and generate weekly lists if due.
     *
     * @return int Number of lists generated
     */
    public function processAllPlans(): int
    {
        $generated = 0;

        $plans = InventoryCyclePlan::active()
            ->where(function ($q) {
                $q->whereNull('next_due_date')
                  ->orWhere('next_due_date', '<=', now()->toDateString());
            })
            ->get();

        foreach ($plans as $plan) {
            // Check if today matches the counting day
            $today = strtolower(now()->format('l')); // e.g., 'sunday'
            if ($plan->next_due_date && $plan->next_due_date->gt(now())) {
                continue; // Not due yet
            }

            $result = $this->generateForPlan($plan);
            if ($result) {
                $generated++;
            }
        }

        return $generated;
    }

    /**
     * Reset cycle counters when a cycle is complete.
     */
    private function resetCycle(InventoryCyclePlan $plan): void
    {
        // Reset count_in_cycle for all items in this warehouse
        ProductAbcClassification::where('warehouse_code', $plan->warehouse_code)
            ->update(['count_in_cycle' => 0]);

        $plan->update([
            'current_week_number' => 0,
            'current_cycle_start' => now()->toDateString(),
        ]);
    }
}
