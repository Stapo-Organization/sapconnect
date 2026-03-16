<?php

use Illuminate\Support\Facades\DB;
use App\Models\Automation;

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- CRONTAB CHECK ---\n";
// Attempt to read crontab (might fail if www-data doesn't have one, but we are running as sapapimuntajat)
$crontab = shell_exec('crontab -l 2>&1');
echo $crontab ? $crontab : "No crontab found or permission denied.\n";

echo "\n--- LARAVEL SCHEDULE CHECK ---\n";
Artisan::call('schedule:list');
echo Artisan::output();

echo "\n--- AUTOMATIONS DB CHECK ---\n";
$automations = Automation::all();
foreach ($automations as $a) {
    echo "ID: {$a->id} | Name: {$a->name} | Code: {$a->code} | Active: " . ($a->is_active ? 'YES' : 'NO') . " | Freq: {$a->schedule_frequency} | Sig: {$a->command_signature}\n";
}
