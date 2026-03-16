<?php

require __DIR__ . '/vendor/autoload.php';

$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Spatie\Permission\Models\Role;

echo "--- STRICT ACCESS VERIFICATION START ---\n";

$role = Role::where('name', 'Operator')->first();
if (!$role) {
    echo "[FAIL] Role 'Operator' not found.\n";
    exit(1);
}

// Allowed List
$allowed = [
    'view_any_sap_import',
    'view_sap_import',
    'download_template_sap_import',
    'run_import_sap_import',
    'view_any_api_log',
    'view_api_log',
];

$allPermissions = $role->permissions->pluck('name')->toArray();

$unexpected = array_diff($allPermissions, $allowed);
$missing = array_diff($allowed, $allPermissions);

if (count($missing) > 0) {
    echo "[FAIL] Missing required permissions:\n";
    print_r($missing);
} else {
    echo "[PASS] All required permissions present.\n";
}

if (count($unexpected) > 0) {
    echo "[FAIL] FOUND UNEXPECTED PERMISSIONS (Security Risk):\n";
    print_r($unexpected);
} else {
    echo "[PASS] No unexpected permissions found. Role is strictly scoped.\n";
}

echo "--- STRICT ACCESS VERIFICATION END ---\n";
