<?php
// Replace the target list of an in-progress HUB counting session that has NO lines yet (sapconnect DB only).
// env: SESSION_ID TARGETS NOTES_FILE PUSH_TITLE PUSH_BODY
$base = getenv('APP_BASE') ?: '/home/sapapimuntajat/sapconnect_app';
require $base . '/vendor/autoload.php';
$app = require $base . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$c = \App\Models\InventoryCounting::findOrFail((int) getenv('SESSION_ID'));
if ($c->status !== 'in_progress' || $c->lines()->count() > 0) { fwrite(STDERR, "session not empty / not in progress\n"); exit(2); }
$targets = json_decode(file_get_contents(getenv('TARGETS')), true);
if (!is_array($targets) || !$targets) { fwrite(STDERR, "bad targets\n"); exit(2); }
$c->update(['target_items' => $targets, 'total_target_items' => count($targets), 'notes' => file_get_contents(getenv('NOTES_FILE'))]);
try {
    (new \App\Services\NotificationService())->pushToWarehouseUsers($c->warehouse_code, getenv('PUSH_TITLE'), getenv('PUSH_BODY'),
        ['type' => 'cycle_due', 'session_id' => (string) $c->id, 'warehouse_code' => $c->warehouse_code]);
    $push = 'sent';
} catch (\Throwable $e) { $push = 'failed: ' . $e->getMessage(); }
echo json_encode(['id' => $c->id, 'targets' => count($targets), 'push' => $push], JSON_UNESCAPED_UNICODE) . "\n";
