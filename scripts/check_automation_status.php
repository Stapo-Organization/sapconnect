<?php

use App\Models\Automation;
use App\Models\AutomationLog;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- AUTOMATIONS ---\n";
$automations = Automation::all();
foreach ($automations as $a) {
    echo "ID: {$a->id} | Name: {$a->name} | Code: {$a->code} | Last Run: {$a->last_run_at} | Status: {$a->last_run_status}\n";
    echo "   Command: {$a->command_signature} | Freq: {$a->schedule_frequency} | Active: " . ($a->is_active ? 'YES' : 'NO') . "\n";
}

echo "\n--- RECENT LOGS ---\n";
$logs = AutomationLog::latest()->take(5)->get();
foreach ($logs as $l) {
    echo "[{$l->created_at}] ({$l->automation_id}) {$l->status}: " . substr($l->message, 0, 100) . "...\n";
}
