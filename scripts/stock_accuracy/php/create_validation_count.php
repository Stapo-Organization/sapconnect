<?php
// One-off: open the 50-item validation cycle-count task for RUH010 in the HUB backend.
// Writes ONLY to the sapconnect DB (inventory_countings) and sends the standard push — nothing touches SAP.
// Run ON THE SERVER as the app user:
//   scp scripts/stock_accuracy/php/create_validation_count.php scripts/stock_accuracy/validation_targets_RUH010.json alofq:/tmp/
//   ssh alofq 'sudo -n chmod 644 /tmp/validation_targets_RUH010.json /tmp/create_validation_count.php && sudo -n -u sapapimuntajat /opt/cpanel/ea-php82/root/usr/bin/php /tmp/create_validation_count.php'
$base = getenv('APP_BASE') ?: '/home/sapapimuntajat/sapconnect_app';
$targetsFile = getenv('TARGETS') ?: '/tmp/validation_targets_RUH010.json';
require $base . '/vendor/autoload.php';
$app = require $base . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$targets = json_decode(file_get_contents($targetsFile), true);
if (!is_array($targets) || count($targets) !== 50) { fwrite(STDERR, "bad targets file\n"); exit(2); }
$existing = \App\Models\InventoryCounting::where('warehouse_code', 'RUH010')->where('status', 'in_progress')->where('notes', 'like', 'جرد تحقق%')->first();
if ($existing) { echo json_encode(['already_exists' => $existing->id]) . "\n"; exit(0); }
$notes = "جرد تحقق من تحليل بيانات SAP — 50 صنفاً مختارة بعناية (ليست قائمة ABC الأسبوعية).\n"
       . "الهدف: تأكيد أو نفي التحليل، لذلك العيّنة فيها أصناف نتوقع خللها لأسباب مختلفة وأصناف نتوقع مطابقتها.\n"
       . "A = متوقع خلل قوي (مخزون وهمي / تبديل أشقاء / بصمة مباشرة) · B = متوقع خلل محتمل (منتهي الصلاحية، هبوط بيع، كراتين الافتتاح) · C = عيّنة ضابطة متوقع مطابقتها.\n"
       . "تعليمات: جرد أعمى (لا تنظر للرصيد)، عدّ كل الوحدات على الرف والمخزن بما فيها المنتهية الصلاحية، وعند صنف الشقيق اعدّ الشقيقَين معاً بعناية، وإذا لم تجد الصنف إطلاقاً أدخل كوده يدوياً بكمية 0 — الصفر معلومة مهمة.";
$c = \App\Models\InventoryCounting::create([
    'warehouse_code' => 'RUH010', 'warehouse_name' => 'King Fahad Store - RUH', 'status' => \App\Models\InventoryCounting::STATUS_IN_PROGRESS,
    'counting_type' => \App\Models\InventoryCounting::TYPE_CYCLE, 'scheduled_date' => now()->toDateString(), 'priority' => 'high', 'cycle_plan_id' => null,
    'target_items' => $targets, 'total_target_items' => count($targets), 'notes' => $notes,
]);
try {
    (new \App\Services\NotificationService())->pushToWarehouseUsers('RUH010', 'مهمة جرد تحقق — معرض الملك فهد',
        "50 صنفاً مختارة لتأكيد تحليل المخزون. جرد أعمى؛ إذا لم تجد الصنف سجّل 0.", ['type' => 'cycle_due', 'session_id' => (string) $c->id, 'warehouse_code' => 'RUH010']);
    $push = 'sent';
} catch (\Throwable $e) { $push = 'failed: ' . $e->getMessage(); }
echo json_encode(['id' => $c->id, 'targets' => count($targets), 'push' => $push, 'created_at' => (string) $c->created_at], JSON_UNESCAPED_UNICODE) . "\n";
