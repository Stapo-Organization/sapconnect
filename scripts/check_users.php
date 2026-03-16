<?php
// check_users.php

require __DIR__ . '/vendor/autoload.php';

$app = require __DIR__ . '/bootstrap/app.php';

$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;

echo "--- USER AUDIT START ---\n";
$users = User::with('tokens')->get();

if ($users->isEmpty()) {
    echo "No users found.\n";
} else {
    foreach ($users as $user) {
        echo "ID: {$user->id}\n";
        echo "Name: {$user->name}\n";
        echo "Email: {$user->email}\n";
        echo "Mobile: {$user->mobile_number}\n";
        echo "Warehouse Code: '" . ($user->warehouse_code ?? 'NULL') . "'\n";
        echo "Token Count: " . $user->tokens->count() . "\n";
        foreach ($user->tokens as $token) {
            echo " - Token ID: {$token->id} | Last Used: {$token->last_used_at}\n";
        }
        echo "--------------------------\n";
    }
}
echo "--- USER AUDIT END ---\n";
