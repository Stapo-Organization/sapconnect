<?php

$dir = __DIR__ . '/../app/Filament/Resources';
$files = glob($dir . '/*.php');

foreach ($files as $file) {
    if (basename($file) === 'StockTransferResource.php') {
        continue;
    }

    $content = file_get_contents($file);
    
    // Check if the file is a Resource class
    if (str_contains($content, 'extends Resource')) {
        // If it doesn't already have canViewAny
        if (!str_contains($content, 'function canViewAny')) {
            $replacement = "$1\n\n    public static function canViewAny(): bool\n    {\n        return !auth()->user()->hasRole('Branch Manager');\n    }\n";
            $content = preg_replace('/(class [a-zA-Z0-9_]+ extends Resource\n\{)/', $replacement, $content);
            file_put_contents($file, $content);
            echo "Updated " . basename($file) . "\n";
        } else {
            echo "Skipped " . basename($file) . " (already has canViewAny)\n";
        }
    }
}
