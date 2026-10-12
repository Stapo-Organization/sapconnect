<?php

use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * "Accountant": a limited admin role that can open only ShipGo Customers
 * (see App\Support\PanelAccess). Seeds the first accountant account.
 * Idempotent: an existing role/user is kept; the password is set only when
 * the user is created here.
 */
return new class extends Migration
{
    public function up(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $role = Role::firstOrCreate(['name' => 'Accountant', 'guard_name' => 'web']);

        $user = User::firstOrCreate(
            ['email' => 'e.hasan@ppte.sa'],
            ['name' => 'E. Hasan', 'password' => Hash::make('12345678')]
        );

        if (!$user->hasRole($role)) {
            $user->assignRole($role);
        }
    }

    public function down(): void
    {
        // Keep the user; only detach the role.
        if ($user = User::where('email', 'e.hasan@ppte.sa')->first()) {
            $user->removeRole('Accountant');
        }
        Role::where('name', 'Accountant')->where('guard_name', 'web')->delete();
    }
};
