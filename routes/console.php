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

// ── Quality Control Scheduled Tasks ─────────────────────────────
Schedule::command('quality:generate-tasks')->dailyAt('05:30'); // Daily 5:30 AM (idempotent)
Schedule::command('quality:send-reminders')->dailyAt('07:15'); // Daily 7:15 AM (push only)

// ── Zooboxi Intelligence Pipeline (DB-only; reads SAP only via the GRPO importer) ──
// Order matters: arrivals+cost → seed costs → build intelligence → plan clearance.
Schedule::command('sap:sync-goods-receipts')->dailyAt('01:30')->withoutOverlapping(); // arrivals + actual cost
Schedule::command('intelligence:seed-product-costs')->dailyAt('02:00')->withoutOverlapping();
Schedule::command('intelligence:build-products')->dailyAt('02:30')->withoutOverlapping(); // stockout-corrected
Schedule::command('intelligence:plan-clearance')->dailyAt('03:10')->withoutOverlapping(); // after build + ABC (Sat)
Schedule::command('intelligence:build-associations')->weeklyOn(0, '04:00')->withoutOverlapping(); // FBT, Sunday 4 AM

// ── Marketing / Ads Automation ──────────────────────────────────
Schedule::command('marketing:suggest-campaigns --per-type=60 --limit=300')->dailyAt('05:15')->withoutOverlapping(); // suggest-only; owner approves in app
Schedule::command('marketing:lifecycle')->everyThirtyMinutes(); // activate scheduled / expire ended

// ── Showroom Pulse (نبض المعرض) — per-branch decision intelligence ──
// After the intelligence pipeline (build-products 02:30). build-branch-pulse depends on build-branch-products.
Schedule::command('intelligence:build-branch-products')->dailyAt('04:30')->withoutOverlapping();
Schedule::command('intelligence:build-branch-pulse')->dailyAt('04:50')->withoutOverlapping();

