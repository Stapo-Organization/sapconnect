<?php

namespace App\Console\Commands;

use App\Models\InventoryCounting;
use App\Services\NotificationService;
use App\Services\NotificationRouter;
use App\Support\NotificationAudience;
use Illuminate\Console\Command;

class SendCycleReminders extends Command
{
    protected $signature = 'counting:send-cycle-reminders';
    protected $description = 'Push reminders to managers for due/overdue cycle counting sessions (push only, de-duped per day)';

    public function handle(): int
    {
        $router = new NotificationRouter(new NotificationService());

        $sessions = InventoryCounting::query()
            ->where('counting_type', 'cycle')
            ->where('status', 'in_progress')
            ->whereNotNull('scheduled_date')
            ->where('scheduled_date', '<=', now()->toDateString())
            ->where(function ($q) {
                $q->whereNull('last_reminded_at')
                  ->orWhereDate('last_reminded_at', '<', now()->toDateString());
            })
            ->get();

        $sent = 0;
        foreach ($sessions as $s) {
            $overdue = $s->scheduled_date && $s->scheduled_date->lt(now()->startOfDay());
            $title = $overdue ? 'تذكير: جرد دوري متأخر ⏰' : 'تذكير: جرد دوري مستحق';
            $body = "لديك مهمة جرد دوري ({$s->total_target_items} صنف) في " . ($s->warehouse_name ?? $s->warehouse_code);

            try {
                $router->route('cycle_count_due', NotificationAudience::warehouseUsers($s->warehouse_code), [
                    'title' => $title,
                    'body'  => $body,
                    'data'  => [
                        'type' => 'cycle_due',
                        'session_id' => (string) $s->id,
                        'warehouse_code' => $s->warehouse_code,
                    ],
                    'email_variables' => [
                        'warehouse' => $s->warehouse_name ?? $s->warehouse_code,
                        'items' => $s->total_target_items,
                    ],
                ]);
                $s->update(['last_reminded_at' => now()]);
                $sent++;
            } catch (\Throwable $e) {
                $this->error("Reminder failed for #{$s->id}: " . $e->getMessage());
            }
        }

        $this->info("✅ Cycle reminders processed: {$sent} session(s).");
        return self::SUCCESS;
    }
}
