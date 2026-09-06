<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\MrsoolDelivery;
use App\Services\Mrsool\MrsoolDeliveryService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Polls Mrsool (مرسول) for every non-terminal delivery.
 *
 * Registered as an everyMinute automation, but it is free at rest: it returns
 * immediately when the integration is disabled or no courier is out. Webhooks
 * are the primary signal — this is the safety net for a webhook that never
 * arrived (Mrsool sends no signature and offers no redelivery we can trigger).
 *
 * A row stuck in `searching` for more than 6 hours is retired locally as
 * EXPIRED, but only AFTER a GET confirms Mrsool still has not assigned anyone —
 * we never invent a terminal state.
 */
class SyncMrsoolDeliveries extends Command
{
    private MrsoolDeliveryService $mrsool;

    protected $signature = 'mrsool:sync-active {--dry : Report what would be synced, write nothing}';
    protected $description = 'Sync all active Mrsool deliveries from the Mrsool LaaS API';

    private const STUCK_HOURS = 6;

    public function handle(MrsoolDeliveryService $mrsool): int
    {
        $this->mrsool = $mrsool;

        if (!$mrsool->enabled()) {
            $this->warn('Mrsool is disabled (services.mrsool.enabled=false). Nothing to do.');
            return self::SUCCESS;
        }

        $active = MrsoolDelivery::active()->whereNotNull('mrsool_order_id')->get();
        if ($active->isEmpty()) {
            $this->info('No active Mrsool deliveries.');
            return self::SUCCESS;
        }

        if ($this->option('dry')) {
            $this->line("Would sync {$active->count()} active delivery(ies).");
            return self::SUCCESS;
        }

        $lock = Cache::lock('mrsool:sync-active', 120);
        if (!$lock->get()) {
            $this->warn('Another sync run is in progress — skipping.');
            return self::SUCCESS;
        }

        $automation = Automation::where('command_signature', 'mrsool:sync-active')->first();
        $automation?->update(['last_run_at' => now(), 'last_run_status' => 'running']);

        $changed = 0;
        $failed = 0;

        try {
            foreach ($active as $delivery) {
                try {
                    if ($mrsool->sync($delivery)) {
                        $changed++;
                    }
                    $this->retireIfStuck($delivery->refresh());
                } catch (\Throwable $e) {
                    $failed++;
                    Log::warning('mrsool: sync-active failed for delivery: ' . $e->getMessage(), [
                        'context'     => 'mrsool',
                        'delivery_id' => $delivery->id,
                    ]);
                }
            }
        } finally {
            $lock->release();
        }

        $message = "Synced {$active->count()} delivery(ies): {$changed} changed, {$failed} failed.";
        $this->info($message);

        if ($automation) {
            $status = $failed ? 'partial' : 'success';
            $automation->update(['last_run_status' => $status]);
            AutomationLog::create([
                'automation_id' => $automation->id,
                'status'        => $status,
                'message'       => $message,
            ]);
        }

        return self::SUCCESS;
    }

    /**
     * Retire a delivery that has been searching for a courier far too long.
     * sync() has just confirmed the remote state, so this only fires when
     * Mrsool itself is still stuck at COURIER_PENDING.
     */
    private function retireIfStuck(MrsoolDelivery $delivery): void
    {
        if ($delivery->isTerminal() || $delivery->phase !== MrsoolDelivery::PHASE_SEARCHING) {
            return;
        }
        if (!$delivery->requested_at || $delivery->requested_at->gt(now()->subHours(self::STUCK_HOURS))) {
            return;
        }

        $this->mrsool->retireStuck($delivery);

        $this->warn("Delivery #{$delivery->id} retired locally (searching > " . self::STUCK_HOURS . 'h).');
    }
}
