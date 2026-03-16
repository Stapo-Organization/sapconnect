<?php

$dir = __DIR__ . '/app/Filament/Resources/';
$filesToHide = [
    'AlrajhiTransactionResource.php',
    'ApiLogResource.php',
    'ApiTransformerResource.php',
    'AutomationResource.php',
    'EmailLogResource.php',
    'EmailNotificationResource.php',
    'PermissionResource.php',
    'RoleResource.php',
    'SmsCampaignResource.php',
    'UserResource.php',
    'ZidStoreResource.php'
];

foreach ($filesToHide as $file) {
    $path = $dir . $file;
    if (!file_exists($path)) {
        echo "Missing: $file\n";
        continue;
    }
    
    $content = file_get_contents($path);
    
    // Check if canViewAny exists
    if (strpos($content, 'public static function canViewAny(): bool') !== false) {
        $content = preg_replace(
            '/return !auth\(\)->user\(\)->hasRole\([^)]+\);/',
            "return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);",
            $content
        );
        $content = preg_replace(
            '/return !auth\(\)->user\(\)->hasAnyRole\([^)]+\);/',
            "return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);",
            $content
        );
    } else {
        // Insert it right after the class declaration
        $classString = "class " . str_replace('.php', '', $file) . " extends Resource\n{";
        if (strpos($content, $classString) !== false) {
            $replacement = $classString . "\n    public static function canViewAny(): bool\n    {\n        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);\n    }\n";
            $content = str_replace($classString, $replacement, $content);
        } else {
            // Try single line brace
            $classString2 = "class " . str_replace('.php', '', $file) . " extends Resource {";
            if (strpos($content, $classString2) !== false) {
                $replacement = $classString2 . "\n    public static function canViewAny(): bool\n    {\n        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);\n    }\n";
                $content = str_replace($classString2, $replacement, $content);
            } else {
                echo "Could not inject into $file\n";
                continue;
            }
        }
    }
    
    file_put_contents($path, $content);
    echo "Updated $file\n";
}
