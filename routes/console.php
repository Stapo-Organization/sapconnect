<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

use Illuminate\Support\Facades\Schedule;
// Dynamically schedule active automations
\App\Console\Commands\AutomationSchedule::schedule(Schedule::getFacadeRoot());

// ── Supply Chain Scheduled Tasks ──────────────────────────────────
Schedule::command('supply-chain:check-contracts')->dailyAt('08:00');
Schedule::command('supply-chain:check-overdue-payments')->dailyAt('09:00');
Schedule::command('sap:sync-po-status')->everyFourHours();

// ── Cycle Counting Scheduled Tasks ──────────────────────────────
Schedule::command('counting:classify-abc')->weeklyOn(6, '03:00'); // Saturday 3 AM
Schedule::command('counting:generate-weekly-lists')->dailyAt('06:00'); // Daily 6 AM
Schedule::command('counting:send-cycle-reminders')->dailyAt('07:00'); // Daily 7 AM (push only)

