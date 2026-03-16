<?php

use Illuminate\Database\Migrations\Migration;
use App\Models\User;
use Spatie\Permission\Models\Role;
use Illuminate\Support\Facades\Hash;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Create Super Admin Role
        $role = Role::firstOrCreate(['name' => 'Super Admin', 'guard_name' => 'web']);

        // 2. Create User
        $user = User::firstOrCreate(
            ['email' => 'admin@muntajat.sa'],
            [
                'name' => 'Super Admin',
                'password' => Hash::make('12345678'), // Default password
                'email_verified_at' => now(),
            ]
        );

        // 3. Assign Role
        $user->assignRole($role);
    }

    public function down(): void
    {
        // No down
    }
};
