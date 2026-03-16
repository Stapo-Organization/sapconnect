<?php

require __DIR__ . '/vendor/autoload.php';

$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

echo "--- VERIFICATION START ---\n";

// 1. Check User
$user = User::where('email', 'mubarak@muntajat.sa')->first();
if ($user) {
    echo "[PASS] User 'mubarak@muntajat.sa' exists. ID: " . $user->id . "\n";
} else {
    echo "[FAIL] User 'mubarak@muntajat.sa' NOT FOUND.\n";
    exit(1);
}

// 2. Check Role Assignment
if ($user->hasRole('Operator')) {
    echo "[PASS] User has 'Operator' role.\n";
} else {
    echo "[FAIL] User DOES NOT have 'Operator' role.\n";
}

// 3. Check Role Permissions
$role = Role::where('name', 'Operator')->first();
if ($role) {
    echo "[INFO] 'Operator' role permissions:\n";
    foreach ($role->permissions as $perm) {
        echo " - " . $perm->name . "\n";
    }

    $required = ['download_template_sap_import', 'run_import_sap_import'];
    foreach ($required as $req) {
        if ($role->hasPermissionTo($req)) {
            echo "[PASS] Permission '$req' is assigned.\n";
        } else {
            echo "[FAIL] Permission '$req' is MISSING.\n";
        }
    }
} else {
    echo "[FAIL] Role 'Operator' not found.\n";
}

echo "--- VERIFICATION END ---\n";
