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

