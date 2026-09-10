<?php
// Standalone harness for the pure gate: WP shims, fake clock, fake history.
// Run: php tests/push-gate-test.php  (no WordPress needed)
define('ABSPATH', '/');
define('MINUTE_IN_SECONDS', 60); define('HOUR_IN_SECONDS', 3600); define('DAY_IN_SECONDS', 86400);
$GLOBALS['opts'] = [];
function get_option($k, $d = null) { return $GLOBALS['opts'][$k] ?? $d; }
function apply_filters($h, $v) { return $v; }
require __DIR__ . '/../includes/push/class-zooboxi-push-gate.php';

$tz = new DateTimeZone('Asia/Riyadh');
$at = fn(string $s) => (new DateTimeImmutable($s, $tz))->getTimestamp();
$fmt = fn(int $t) => (new DateTimeImmutable('@' . $t))->setTimezone($tz)->format('D H:i');
$fails = 0;
function check($name, $cond) { global $fails; echo ($cond ? '  ok  ' : '  FAIL') . " $name\n"; if (!$cond) $fails++; }

$M = ['tier' => 'marketing', 'text_hash' => 'aaa'];
$S = ['tier' => 'service', 'text_hash' => 'bbb'];
$T = ['tier' => 'transactional', 'text_hash' => 'ccc'];

// 1. transactional always sends, even at 3 AM with a full history
$d = Zooboxi_Push_Gate::decide($T, [['tier'=>'marketing','sent_at'=>$at('2026-09-14 12:00'),'text_hash'=>'x']], true, $at('2026-09-14 03:00'));
check('transactional at 3AM, control → send', $d['action'] === 'send');

// 2. holdout never receives
$d = Zooboxi_Push_Gate::decide($M, [], true, $at('2026-09-14 12:00'));
check('control → skip control', $d['action'] === 'skip' && $d['reason'] === 'control');

// 3. quiet hours defer: marketing at 23:00 → 09:00 next day; service at 23:00 → 08:00
$d = Zooboxi_Push_Gate::decide($M, [], false, $at('2026-09-14 23:00'));
check('marketing 23:00 → defer to Tue 09:00 ('.$fmt($d['not_before']).')', $d['action']==='defer' && $fmt($d['not_before'])==='Tue 09:00');
$d = Zooboxi_Push_Gate::decide($S, [], false, $at('2026-09-14 23:00'));
check('service 23:00 → defer to Tue 08:00 ('.$fmt($d['not_before']).')', $d['action']==='defer' && $fmt($d['not_before'])==='Tue 08:00');
$d = Zooboxi_Push_Gate::decide($M, [], false, $at('2026-09-14 02:30'));
check('marketing 02:30 → defer to Mon 09:00 ('.$fmt($d['not_before']).')', $d['action']==='defer' && $fmt($d['not_before'])==='Mon 09:00');
$d = Zooboxi_Push_Gate::decide($M, [], false, $at('2026-09-14 08:30'));
check('marketing 08:30 → defer to 09:00 (window)', $d['action']==='defer' && $d['reason']==='marketing_window' && $fmt($d['not_before'])==='Mon 09:00');
$d = Zooboxi_Push_Gate::decide($M, [], false, $at('2026-09-14 21:45'));
check('marketing 21:45 → defer to Tue 09:00', $d['action']==='defer' && $fmt($d['not_before'])==='Tue 09:00');
$d = Zooboxi_Push_Gate::decide($S, [], false, $at('2026-09-14 08:30'));
check('service 08:30 → send', $d['action']==='send');

// 4. Friday pause (2026-09-18 is a Friday)
$d = Zooboxi_Push_Gate::decide($M, [], false, $at('2026-09-18 12:00'));
check('marketing Fri 12:00 → defer to 13:15', $d['action']==='defer' && $d['reason']==='friday_pause' && $fmt($d['not_before'])==='Fri 13:15');
$d = Zooboxi_Push_Gate::decide($S, [], false, $at('2026-09-18 12:00'));
check('service Fri 12:00 → send', $d['action']==='send');

// 5. expiry beats deferral
$d = Zooboxi_Push_Gate::decide($M + ['expires_at' => $at('2026-09-15 07:00')], [], false, $at('2026-09-14 23:00'));
check('expires before window opens → skip expired', $d['action']==='skip' && $d['reason']==='expired');

// 6. caps
$noon = $at('2026-09-14 12:00');
$h = [['tier'=>'marketing','sent_at'=>$at('2026-09-14 10:00'),'text_hash'=>'x']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('second marketing same day → cap_daily', $d['action']==='skip' && $d['reason']==='cap_daily');
$h = [['tier'=>'marketing','sent_at'=>$at('2026-09-13 20:00'),'text_hash'=>'x']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('marketing 16h after last → cap_gap', $d['action']==='skip' && $d['reason']==='cap_gap');
$h = [['tier'=>'marketing','sent_at'=>$at('2026-09-13 14:00'),'text_hash'=>'x']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('marketing 22h after last → send', $d['action']==='send');
$h = [
  ['tier'=>'marketing','sent_at'=>$at('2026-09-09 12:00'),'text_hash'=>'1'],
  ['tier'=>'marketing','sent_at'=>$at('2026-09-11 12:00'),'text_hash'=>'2'],
  ['tier'=>'marketing','sent_at'=>$at('2026-09-13 12:00'),'text_hash'=>'3'],
];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('3 marketing this week → cap_weekly', $d['action']==='skip' && $d['reason']==='cap_weekly');
$h = [['tier'=>'service','sent_at'=>$at('2026-09-14 10:00'),'text_hash'=>'x'], ['tier'=>'service','sent_at'=>$at('2026-09-14 07:00'),'text_hash'=>'y']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('2 service today → marketing hits total cap_daily', $d['action']==='skip' && $d['reason']==='cap_daily');
$h = [['tier'=>'service','sent_at'=>$at('2026-09-14 10:00'),'text_hash'=>'x']];
$d = Zooboxi_Push_Gate::decide($S, $h, false, $noon);
check('service 2h after service → cap_gap', $d['action']==='skip' && $d['reason']==='cap_gap');
$h = [['tier'=>'service','sent_at'=>$at('2026-09-14 08:30'),'text_hash'=>'x']];
$d = Zooboxi_Push_Gate::decide($S, $h, false, $noon);
check('service 3.5h after service → send', $d['action']==='send');
$h = [['tier'=>'transactional','sent_at'=>$at('2026-09-14 11:00'),'text_hash'=>'x'], ['tier'=>'transactional','sent_at'=>$at('2026-09-14 11:30'),'text_hash'=>'y']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('transactional history is ignored → send', $d['action']==='send');

// 7. repeat text
$h = [['tier'=>'marketing','sent_at'=>$at('2026-08-30 12:00'),'text_hash'=>'aaa']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('same text 15 days ago → repeat_text', $d['action']==='skip' && $d['reason']==='repeat_text');
$h = [['tier'=>'marketing','sent_at'=>$at('2026-08-01 12:00'),'text_hash'=>'aaa']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('same text 44 days ago → send', $d['action']==='send');

// 8. options override
$GLOBALS['opts']['zooboxi_push_marketing_per_day'] = '2';
$h = [['tier'=>'marketing','sent_at'=>$at('2026-09-13 14:00'),'text_hash'=>'x'], ['tier'=>'marketing','sent_at'=>$at('2026-09-14 09:30'),'text_hash'=>'y']];
$d = Zooboxi_Push_Gate::decide($M, $h, false, $noon);
check('per_day=2, second marketing 2.5h after first → cap_gap', $d['action']==='skip' && $d['reason']==='cap_gap');

echo $fails === 0 ? "\nALL PASS\n" : "\n$fails FAILED\n";
exit($fails === 0 ? 0 : 1);
