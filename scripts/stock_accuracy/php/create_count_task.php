<?php
// Open a cycle-count task in the HUB backend from a targets JSON. Writes ONLY to the sapconnect DB
// (inventory_countings) and sends the standard push — nothing touches SAP.
// Run ON THE SERVER as the app user with env: TARGETS=<json> NOTES_FILE=<txt> MARK=<notes prefix for dedupe>
//   PUSH_TITLE=<title> PUSH_BODY=<body> [WAREHOUSE=RUH010] [WAREHOUSE_NAME=...] [EXPECT=<n>]
$base = getenv('APP_BASE') ?: '/home/sapapimuntajat/sapconnect_app';
$wh = getenv('WAREHOUSE') ?: 'RUH010';
$whName = getenv('WAREHOUSE_NAME') ?: 'King Fahad Store - RUH';
$targetsFile = getenv('TARGETS') ?: '/tmp/count_targets.json';
$notes = file_get_contents(getenv('NOTES_FILE') ?: '/tmp/count_notes.txt');
$mark = getenv('MARK') ?: mb_substr($notes, 0, 20);
require $base . '/vendor/autoload.php';
$app = require $base . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$targets = json_decode(file_get_contents($targetsFile), true);
$expect = (int) (getenv('EXPECT') ?: 0);
if (!is_array($targets) || !$targets || ($expect && count($targets) !== $expect)) { fwrite(STDERR, "bad targets file\n"); exit(2); }
$existing = \App\Models\InventoryCounting::where('warehouse_code', $wh)->where('status', 'in_progress')->where('notes', 'like', $mark . '%')->first();
if ($existing) { echo json_encode(['already_exists' => $existing->id]) . "\n"; exit(0); }
$c = \App\Models\InventoryCounting::create([
    'warehouse_code' => $wh, 'warehouse_name' => $whName, 'status' => \App\Models\InventoryCounting::STATUS_IN_PROGRESS,
    'counting_type' => \App\Models\InventoryCounting::TYPE_CYCLE, 'scheduled_date' => now()->toDateString(), 'priority' => 'high', 'cycle_plan_id' => null,
    'target_items' => $targets, 'total_target_items' => count($targets), 'notes' => $notes,
]);
try {
    (new \App\Services\NotificationService())->pushToWarehouseUsers($wh, getenv('PUSH_TITLE') ?: 'مهمة جرد جديدة',
        getenv('PUSH_BODY') ?: (count($targets) . ' صنفاً'), ['type' => 'cycle_due', 'session_id' => (string) $c->id, 'warehouse_code' => $wh]);
    $push = 'sent';
} catch (\Throwable $e) { $push = 'failed: ' . $e->getMessage(); }
echo json_encode(['id' => $c->id, 'targets' => count($targets), 'push' => $push, 'created_at' => (string) $c->created_at], JSON_UNESCAPED_UNICODE) . "\n";
