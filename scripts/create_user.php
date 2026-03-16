<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Spatie\Permission\Models\Role;
use Illuminate\Support\Facades\Hash;

echo "--- Creating User ---\n";
try {
    $user = User::firstOrCreate(
        ['email' => 'nasr.branch@ppte.sa'],
        [
            'name' => 'Nasr Branch',
            'password' => Hash::make('password'),
            'warehouse_code' => ['RUH002'] // Array since it's typically cast or stored as JSON
        ]
    );

    // Ensure password and warehouse are correct if user already existed
    $user->update([
        'password' => Hash::make('password'),
        'warehouse_code' => ['RUH002']
    ]);

    // Ensure role exists and assign
    $role = Role::firstOrCreate(['name' => 'Branch Manager']);
    $user->assignRole($role);

    echo "Successfully created/updated user: {$user->email}\n";
    echo "Assigned Role: Branch Manager\n";
    echo "Assigned Warehouse: " . json_encode($user->warehouse_code) . "\n";
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
