<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$user = App\Models\User::where('email', 'admin@muntajat.sa')->first();
if ($user) {
    echo "Current Mobile: " . $user->mobile_number . "\n";
    $user->mobile_number = '966500141072';
    $user->saveQuietly(); // Use saveQuietly to avoid mutators if any mess it up further
    echo "Updated Mobile: " . $user->mobile_number . "\n";
} else {
    echo "User not found\n";
}
