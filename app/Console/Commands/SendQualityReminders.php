<?php

namespace App\Console\Commands;

use App\Models\QualityTaskInstance;
use App\Services\NotificationService;
use Illuminate\Console\Command;

class SendQualityReminders extends Command
{
    protected $signature = 'quality:send-reminders';
    protected $description = 'Push reminders for due/overdue pending quality tasks (push only, de-duped per day)';

    public function handle(): int
    {
        $notifier = new NotificationService();

        $instances = QualityTaskInstance::query()
            ->where('status', QualityTaskInstance::STATUS_PENDING)
            ->whereDate('scheduled_date', '<=', now()->toDateString())
            ->where(function ($q) {
                $q->whereNull('last_reminded_at')
                  ->orWhereDate('last_reminded_at', '<', now()->toDateString());
            })
            ->get();

        $sent = 0;
        foreach ($instances as $instance) {
            $overdue = $instance->scheduled_date && $instance->scheduled_date->lt(now()->startOfDay());
            $title = 'تذكير: مهمة جودة' . ($overdue ? ' متأخرة ⏰' : ' مستحقة');
            $body = "{$instance->title} — " . ($instance->warehouse_name ?? $instance->warehouse_code);

            try {
                $notifier->pushToWarehouseUsers($instance->warehouse_code, $title, $body, [
                    'type' => 'quality_due',
                    'instance_id' => $instance->id,
                    'warehouse_code' => $instance->warehouse_code,
                ]);
                $instance->update(['last_reminded_at' => now()]);
                $sent++;
            } catch (\Throwable $e) {
                $this->error("Reminder failed for #{$instance->id}: " . $e->getMessage());
            }
        }

        $this->info("✅ Quality reminders processed: {$sent} instance(s).");
        return self::SUCCESS;
    }
}
