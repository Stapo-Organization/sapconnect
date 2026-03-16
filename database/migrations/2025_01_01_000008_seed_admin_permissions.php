<?php

use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Define all permissions required by the new Policies
        $permissions = [
            // User
            'view_any_user',
            'view_user',
            'create_user',
            'update_user',
            'delete_user',
            // Role
            'view_any_role',
            'view_role',
            'create_role',
            'update_role',
            'delete_role',
            // Permission
            'view_any_permission',
            'view_permission',
            'create_permission',
            'update_permission',
            'delete_permission',
            // ApiTransformer
            'view_any_api_transformer',
            'view_api_transformer',
            'create_api_transformer',
            'update_api_transformer',
            'delete_api_transformer',
        ];

        foreach ($permissions as $p) {
            Permission::firstOrCreate(['name' => $p, 'guard_name' => 'web']);
        }

        // Optional: Assign to a 'Super Admin' role if it exists, to ensure they don't get locked out.
        // But for this task, the goal is locking out 'Operator'.
        // Assuming Super Admin via Filament Shield or Gate::before works independently.
    }

    public function down(): void
    {
        // No down
    }
};
