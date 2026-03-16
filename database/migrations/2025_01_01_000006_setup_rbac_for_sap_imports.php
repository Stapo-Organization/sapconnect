<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Create Permissions
        $permissions = [
            'view_any_sap_import',
            'view_sap_import',
            'create_sap_import',
            'update_sap_import',
            'delete_sap_import',
            'download_template_sap_import',
            'run_import_sap_import',
        ];

        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission, 'guard_name' => 'web']);
        }

        // 2. Create Role
        $role = Role::firstOrCreate(['name' => 'Operator', 'guard_name' => 'web']);

        // 3. Assign Permissions to Role
        $role->givePermissionTo([
            'view_any_sap_import',
            'view_sap_import',
            'download_template_sap_import',
            'run_import_sap_import',
        ]);

        // 4. Create User
        $user = User::firstOrCreate(
            ['email' => 'mubarak@muntajat.sa'],
            [
                'name' => 'Mubarak',
                'password' => Hash::make('12345678'),
            ]
        );

        // 5. Assign Role to User
        if (!$user->hasRole('Operator')) {
            $user->assignRole($role);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Ideally we don't delete the user as they might have created data
        // But we can cleanup permissions and role if strictly needed.
        // For production safety, we usually leave data, but for completeness:

        $user = User::where('email', 'mubarak@muntajat.sa')->first();
        if ($user) {
            $user->removeRole('Operator');
        }

        // We don't delete the Role or Permissions to avoid breaking other potential assignments
        // created in the meantime.
    }
};
