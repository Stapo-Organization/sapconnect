<?php
// php merge_lang.php <app_root> <lang_keys.json> — adds missing keys only, keeps the server's own edits.
[$_, $app, $keysFile] = $argv;
$keys = json_decode(file_get_contents($keysFile), true);
foreach (['ar', 'en'] as $lang) {
    $path = "$app/lang/$lang.json";
    $cur  = json_decode(file_get_contents($path), true) ?: [];
    $n = 0;
    foreach ($keys[$lang] as $k => $v) { if (!array_key_exists($k, $cur)) { $cur[$k] = $v; $n++; } }
    file_put_contents($path, json_encode($cur, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . "\n");
    echo "$lang.json: +$n keys\n";
}
