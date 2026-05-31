<?php
/**
 * Zooboxi Server Check Script
 * TEMPORARY — DELETE AFTER USE
 * Access: https://store.zooboxi.com/zb_check.php?key=zb2026check
 */

// Security check
if (($_GET['key'] ?? '') !== 'zb2026check') {
    http_response_code(403);
    die('Forbidden');
}

header('Content-Type: application/json');

$checks = [];

// 1. PHP Version
$checks['php_version'] = phpversion();
$checks['php_sapi'] = php_sapi_name();

// 2. PHP Extensions
$required_extensions = [
    'mysqli', 'pdo_mysql', 'curl', 'gd', 'mbstring', 
    'xml', 'zip', 'json', 'openssl', 'intl', 'sodium',
    'fileinfo', 'exif', 'imagick'
];
$checks['php_extensions'] = [];
foreach ($required_extensions as $ext) {
    $checks['php_extensions'][$ext] = extension_loaded($ext);
}

// 3. PHP Settings
$checks['php_settings'] = [
    'memory_limit' => ini_get('memory_limit'),
    'max_execution_time' => ini_get('max_execution_time'),
    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'post_max_size' => ini_get('post_max_size'),
    'max_input_vars' => ini_get('max_input_vars'),
    'allow_url_fopen' => ini_get('allow_url_fopen'),
];

// 4. Server Info
$checks['server'] = [
    'software' => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
    'hostname' => gethostname(),
    'os' => php_uname(),
    'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'unknown',
    'home_dir' => getenv('HOME') ?: posix_getpwuid(posix_getuid())['dir'],
];

// 5. Disk Space
$docRoot = $_SERVER['DOCUMENT_ROOT'] ?? '/home/storezooboxi/public_html';
$checks['disk'] = [
    'free_gb' => round(disk_free_space($docRoot) / 1024 / 1024 / 1024, 2),
    'total_gb' => round(disk_total_space($docRoot) / 1024 / 1024 / 1024, 2),
];

// 6. Directory listing
$files = scandir($docRoot);
$checks['public_html_contents'] = array_values(array_diff($files, ['.', '..']));

// 7. Write test
$testFile = $docRoot . '/.zb_write_test';
$checks['writable'] = @file_put_contents($testFile, 'test') !== false;
@unlink($testFile);

// 8. MySQL check
$checks['mysql_available'] = extension_loaded('mysqli');

// 9. WP-CLI
$checks['wp_cli'] = trim(shell_exec('which wp 2>/dev/null') ?: 'not found');

// 10. cURL external test
$ch = curl_init('https://api.wordpress.org/core/version-check/1.7/');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
$wpApiResponse = curl_exec($ch);
$checks['can_reach_wp_api'] = $wpApiResponse !== false;
$wpData = json_decode($wpApiResponse, true);
$checks['latest_wp_version'] = $wpData['offers'][0]['version'] ?? 'unknown';
curl_close($ch);

// Summary
$checks['ready_for_wordpress'] = 
    version_compare(phpversion(), '8.1.0', '>=') &&
    $checks['php_extensions']['mysqli'] &&
    $checks['php_extensions']['curl'] &&
    $checks['php_extensions']['mbstring'] &&
    $checks['php_extensions']['xml'] &&
    $checks['php_extensions']['zip'] &&
    $checks['writable'] &&
    $checks['can_reach_wp_api'];

echo json_encode($checks, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
