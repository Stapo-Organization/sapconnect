<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Console\Scheduling\Schedule;
use App\Models\Automation;
use Illuminate\Support\Facades\Schema;
use Illuminate\Console\Scheduling\Event;

class AutomationSchedule extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:automation-schedule';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Register dynamic automation schedules';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('This command registers automation schedules dynamically.');
    }

    /**
     * Define the application's command schedule.
     */
    public static function schedule(Schedule $schedule): void
    {
        if (!Schema::hasTable('automations')) {
            return;
        }

        try {
            $automations = Automation::where('is_active', true)->get();
            foreach ($automations as $automation) {
                if ($automation->command_signature && $automation->schedule_frequency) {
                    $freq = $automation->schedule_frequency;

                    if (method_exists(Event::class, $freq)) {
                        $schedule->command($automation->command_signature)->$freq();
                    } else {
                        $schedule->command($automation->command_signature)->everyMinute();
                    }
                }
            }
        } catch (\Throwable $e) {
            // Fallback for migration/install time issues
        }
    }
}
