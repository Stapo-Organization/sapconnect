<?php
// Per-item GET of the EXISTING saved query SQLQueries('batchesitems')/List?ItemCode='X' (batch qty + expiry per warehouse). GET only, nothing is created.
// php pull_batches.php --keys=items.txt --out=batches.ndjson.gz
require __DIR__ . '/_bootstrap.php';
$o = argv_opts($argv);
foreach (['keys','out'] as $req) if (empty($o[$req])) { err("missing --{$req}"); exit(2); }
$keys = array_values(array_filter(array_map('trim', file($o['keys']))));
$client = sap_client(500);
$fh = gzopen($o['out'], 'wb9'); $n = 0; $rows = 0; $t0 = microtime(true);
foreach ($keys as $i => $k) {
    try {
        $r = sap_get_retry($client, "SQLQueries('batchesitems')/List", ['ItemCode' => "'{$k}'"]);
        foreach (($r['value'] ?? []) as $row) { $row['_item'] = $k; gzwrite($fh, json_encode($row, JSON_UNESCAPED_UNICODE) . "\n"); $rows++; }
        $n++;
    } catch (\Throwable $e) { err("  {$k}: ERROR [" . $e->getCode() . "] " . substr($e->getMessage(), 0, 160)); }
    if (($i + 1) % 100 === 0) err(sprintf("  %d/%d items, %d batch rows, %.0fs", $i + 1, count($keys), $rows, microtime(true) - $t0));
    usleep(150000);
}
gzclose($fh);
echo json_encode(['items' => $n, 'rows' => $rows, 'out' => $o['out']]) . "\n";
