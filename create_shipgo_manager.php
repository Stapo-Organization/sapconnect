<?php

use App\Models\User;
use App\Models\Warehouse;
use Spatie\Permission\Models\Role;
use Illuminate\Support\Facades\Hash;

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$shipgoWarehouses = Warehouse::where('warehouse_name', 'LIKE', '%shipgo%')
    ->orWhere('warehouse_code', 'LIKE', '%shipgo%')
    ->pluck('warehouse_code')
    ->toArray();

echo "Found " . count($shipgoWarehouses) . " Shipgo warehouses: " . implode(', ', $shipgoWarehouses) . "\n";

// Ensure the role exists
$role = Role::firstOrCreate(['name' => 'Branch Manager']);
echo "Role Branch Manager secured.\n";

try {
    $user = User::updateOrCreate(
        ['email' => 'Info@shipgo.sa'],
        [
            'name' => 'Shipgo Manager',
            'password' => Hash::make('password'),
            'warehouse_code' => $shipgoWarehouses
        ]
    );

    if (!$user->hasRole('Branch Manager')) {
        $user->assignRole('Branch Manager');
    }

    echo "User Info@shipgo.sa created/updated successfully with warehouses: " . implode(', ', $shipgoWarehouses) . "\n";
} catch (\Exception $e) {
    echo "Failed to create Info@shipgo.sa: " . $e->getMessage() . "\n";
}

echo "Done!\n";
