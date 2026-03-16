<?php

use App\Models\User;
use Spatie\Permission\Models\Role;
use Illuminate\Support\Facades\Hash;

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

$branches = [
    [
        'name' => 'النصر',
        'email' => 'nasr.branch@ppte.sa',
        'warehouse' => ['RUH002'],
    ],
    [
        'name' => 'السويدي',
        'email' => 'suwaidi.branch@ppte.sa',
        'warehouse' => ['RUH008'],
    ],
    [
        'name' => 'جدة',
        'email' => 'jeddah.branch@ppte.sa',
        'warehouse' => ['JED002'],
    ],
    [
        'name' => 'الدمام',
        'email' => 'dammam.branch@ppte.sa',
        'warehouse' => ['DMM001'],
    ],
    [
        'name' => 'الخبر',
        'email' => 'khobar.branch@ppte.sa',
        'warehouse' => [], // Unknown warehouse code
    ],
    [
        'name' => 'المدينة',
        'email' => 'madinah.branch@ppte.sa',
        'warehouse' => ['MED001'],
    ],
    [
        'name' => 'أبها',
        'email' => 'abha.branch@ppte.sa',
        'warehouse' => ['ABH001'],
    ],
    [
        'name' => 'عنيزة',
        'email' => 'onaizah.branch@ppte.sa',
        'warehouse' => ['UZH001'],
    ],
    [
        'name' => 'حفر الباطن',
        'email' => 'hafr.branch@ppte.sa',
        'warehouse' => [], // Unknown warehouse code
    ],
    [
        'name' => 'الربيع',
        'email' => 'rabee.branch@ppte.sa',
        'warehouse' => ['RUH004'],
    ],
    [
        'name' => 'الروابي',
        'email' => 'rawabi.branch@ppte.sa',
        'warehouse' => ['RUH007'],
    ],
    [
        'name' => 'قرطبة',
        'email' => 'qurtuba.branch@ppte.sa',
        'warehouse' => ['RUH005'],
    ],
    [
        'name' => 'السليمانية',
        'email' => 'sulaimaniyah.branch@ppte.sa',
        'warehouse' => ['RUH006'],
    ],
];

// Ensure the role exists
$role = Role::firstOrCreate(['name' => 'Branch Manager']);
echo "Role Branch Manager secured.\n";

foreach ($branches as $branch) {
    try {
        $user = User::updateOrCreate(
            ['email' => $branch['email']],
            [
                'name' => 'فرع ' . $branch['name'],
                'password' => Hash::make('password'),
                'warehouse_code' => $branch['warehouse']
            ]
        );

        if (!$user->hasRole('Branch Manager')) {
            $user->assignRole('Branch Manager');
        }

        echo "User {$branch['email']} created/updated successfully.\n";
    } catch (\Exception $e) {
        echo "Failed for {$branch['email']}: " . $e->getMessage() . "\n";
    }
}
echo "Done!\n";
