<?php
// fix_warehouse_code.php

require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;

$id = 5;
$code = 'RUH002';

$user = User::find($id);

if ($user) {
    $user->update(['warehouse_code' => $code]);
    echo "SUCCESS: Updated User '{$user->name}' (ID: {$user->id}) with warehouse_code = '{$code}'\n";
} else {
    echo "ERROR: User ID {$id} not found.\n";
}
