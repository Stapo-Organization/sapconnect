<?php
// Generic paged GET → NDJSON.gz. GET only.
// php pull.php --resource=StockTransfers --filter="..." --select="..." --orderby=DocEntry --page=200 --out=file.ndjson.gz [--skip=N] [--max-pages=N] [--sleep=0.3]
require __DIR__ . '/_bootstrap.php';
$o = argv_opts($argv);
foreach (['resource','out'] as $req) if (empty($o[$req])) { err("missing --{$req}"); exit(2); }
$page = (int) ($o['page'] ?? 200);
$client = sap_client($page);
$q = ['$top' => $page];
if (!empty($o['select']))  $q['$select']  = $o['select'];
if (!empty($o['filter']))  $q['$filter']  = $o['filter'];
if (!empty($o['orderby'])) $q['$orderby'] = $o['orderby'];
$skip = (int) ($o['skip'] ?? 0);
$maxPages = (int) ($o['max-pages'] ?? 100000);
$sleepUs = (int) (((float) ($o['sleep'] ?? 0.3)) * 1e6);
$mode = $skip > 0 ? 'ab' : 'wb';
$fh = gzopen($o['out'], $mode . '9');
if (!$fh) { err("cannot open {$o['out']}"); exit(2); }
$t0 = microtime(true); $rows = 0; $pages = 0;
err("[pull] {$o['resource']} page={$page} skip={$skip} filter=" . ($o['filter'] ?? '-'));
while ($pages < $maxPages) {
    $resp = sap_get_retry($client, $o['resource'], $q + ['$skip' => $skip]);
    $batch = $resp['value'] ?? [];
    if (empty($batch)) break;
    foreach ($batch as $row) { gzwrite($fh, json_encode($row, JSON_UNESCAPED_UNICODE) . "\n"); }
    $n = count($batch); $rows += $n; $skip += $n; $pages++;
    if ($pages % 5 === 1 || $n < $page) err(sprintf("  page %d: +%d rows (total %d, skip=%d, %.0fs)", $pages, $n, $rows, $skip, microtime(true) - $t0));
    if ($sleepUs > 0) usleep($sleepUs);
}
gzclose($fh);
err(sprintf("[pull] done: %d rows in %d pages, %.0fs → %s", $rows, $pages, microtime(true) - $t0, $o['out']));
echo json_encode(['resource'=>$o['resource'],'rows'=>$rows,'pages'=>$pages,'out'=>$o['out'],'ended_skip'=>$skip]) . "\n";
