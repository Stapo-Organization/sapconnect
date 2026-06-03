<?php

namespace App\Services\Quality;

use App\Models\QualityTask;
use App\Models\QualityTaskInstance;
use App\Models\Warehouse;
use App\Services\NotificationService;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;

class QualityTaskGenerationService
{
    /**
     * Generate today's due instances for all active tasks. Idempotent: safe to
     * re-run (firstOrCreate on the unique key); only newly-created instances
     * trigger a push notification.
     */
    public function generateDueInstances(?Carbon $date = null): int
    {
        $date = $date ? $date->copy() : now();
        $generated = 0;

        QualityTask::active()->get()->each(function (QualityTask $task) use ($date, &$generated) {
            $generated += $this->generateForTask($task, $date);
        });

        return $generated;
    }

    /**
     * Generate the due instances for one task on a given date (one per slot).
     * Returns the number of newly-created instances.
     */
    public function generateForTask(QualityTask $task, ?Carbon $date = null): int
    {
        $date = $date ? $date->copy() : now();

        if (!$task->is_active || !$task->runsOn($date)) {
            return 0;
        }

        $warehouse = Warehouse::where('warehouse_code', $task->warehouse_code)->first();
        $created = 0;

        foreach ($task->effectiveSlots() as $slot) {
            $instance = QualityTaskInstance::firstOrCreate(
                [
                    'quality_task_id' => $task->id,
                    'warehouse_code' => $task->warehouse_code,
                    'scheduled_date' => $date->toDateString(),
                    'slot_key' => $slot['key'],
                ],
                [
                    'warehouse_name' => $warehouse?->warehouse_name,
                    'title' => $task->title,
                    'description' => $task->description,
                    'requirements_snapshot' => $task->buildSnapshot($slot),
                    'status' => QualityTaskInstance::STATUS_PENDING,
                    'priority' => $task->priority,
                ]
            );

            if ($instance->wasRecentlyCreated) {
                $created++;
                $this->notify($task, $instance, $warehouse);
            }
        }

        if ($created > 0) {
            $task->update(['last_generated_at' => now()]);
        }

        return $created;
    }

    protected function notify(QualityTask $task, QualityTaskInstance $instance, ?Warehouse $warehouse): void
    {
        try {
            (new NotificationService())->pushToWarehouseUsers(
                $task->warehouse_code,
                'مهمة جودة جديدة',
                "{$task->title} — " . ($warehouse?->warehouse_name ?? $task->warehouse_code),
                [
                    'type' => 'quality_due',
                    'instance_id' => $instance->id,
                    'warehouse_code' => $task->warehouse_code,
                ]
            );
        } catch (\Throwable $e) {
            Log::warning('Quality generation push failed: ' . $e->getMessage());
        }
    }
}
