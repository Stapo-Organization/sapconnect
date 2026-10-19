<?php
// GET Resource(key) for each key → NDJSON.gz (one document per line). GET only.
// php pull_doc_by_key.php --resource=InventoryCountings --keys=1,2,3 --out=file.ndjson.gz
require __DIR__ . '/_bootstrap.php';
$o = argv_opts($argv);
foreach (['resource','keys','out'] as $req) if (empty($o[$req])) { err("missing --{$req}"); exit(2); }
$keys = is_file($o['keys']) ? array_filter(array_map('trim', file($o['keys']))) : array_filter(array_map('trim', explode(',', $o['keys'])));
$client = sap_client(1);
$fh = gzopen($o['out'], 'wb9');
$ok = 0;
foreach ($keys as $k) {
    $t = microtime(true);
    try {
        $doc = sap_get_retry($client, "{$o['resource']}({$k})", []);
        gzwrite($fh, json_encode($doc, JSON_UNESCAPED_UNICODE) . "\n");
        $ok++;
        $lines = 0; foreach ($doc as $v) if (is_array($v) && isset($v[0]) && is_array($v[0])) $lines = max($lines, count($v));
        err(sprintf("  %s(%s): ok, ~%d lines, %.1fs", $o['resource'], $k, $lines, microtime(true) - $t));
    } catch (\Throwable $e) {
        err("  {$o['resource']}({$k}): ERROR [" . $e->getCode() . "] " . substr($e->getMessage(), 0, 200));
    }
}
gzclose($fh);
echo json_encode(['resource'=>$o['resource'],'docs'=>$ok,'out'=>$o['out']]) . "\n";
