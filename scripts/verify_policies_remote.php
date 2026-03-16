<?php

require __DIR__ . '/vendor/autoload.php';

$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use App\Models\ApiTransformer;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;
use Illuminate\Support\Facades\Gate;

echo "--- POLICY ENFORCEMENT VERIFICATION START ---\n";

$user = User::where('email', 'mubarak@muntajat.sa')->first();
if (!$user) {
    echo "[FAIL] User 'mubarak@muntajat.sa' not found.\n";
    exit(1);
}

// Emulate login
auth()->login($user);

$models = [
    'User' => User::class,
    'Role' => Role::class,
    'Permission' => Permission::class,
    'ApiTransformer' => ApiTransformer::class,
];

foreach ($models as $name => $class) {
    echo "Checking access for $name:\n";

    // Check viewAny (Listing)
    if (Gate::any(['viewAny'], $class)) {
        echo " - [FAIL] User CAN viewAny $name (Should be DENIED).\n";
    } else {
        echo " - [PASS] User DENIED viewAny $name.\n"; // Expected
    }

    // Check create
    if (Gate::any(['create'], $class)) {
        echo " - [FAIL] User CAN create $name (Should be DENIED).\n";
    } else {
        echo " - [PASS] User DENIED create $name.\n";
    }
}

echo "--- POLICY ENFORCEMENT VERIFICATION END ---\n";
