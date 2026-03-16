<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use Spatie\Permission\Models\Role;

echo "--- Creating Roles ---\n";
try {
    $role = Role::firstOrCreate(['name' => 'Branch Manager']);
    echo "Successfully ensured role exists: {$role->name}\n";
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
