<?php

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$strings = [];
$files = \File::allFiles(app_path('Filament'));
foreach ($files as $file) {
    preg_match_all('/__\([\'"](.*?)[\'"]\)/', $file->getContents(), $matches);
    if (!empty($matches[1])) {
        foreach($matches[1] as $match) {
            $strings[$match] = ""; // Empty translation to start
        }
    }
}
ksort($strings);
echo json_encode($strings, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
