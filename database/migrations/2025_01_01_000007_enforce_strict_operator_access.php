<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Get the Operator Role
        $role = Role::where('name', 'Operator')->first();
        if (!$role) {
            return; // Role might not exist in all environments yet, safe ignore
        }

        // 2. Revoke Sensitive Permissions (if they were ever assigned or implied)
        // We explicitly ensure they DON'T have these.
        // Assuming standard Spatie naming conventions or Filament conventions.
        // We will just sync the exact allowed list to be safe.

        $allowed = [
            'view_any_sap_import',
            'view_sap_import',
            'download_template_sap_import',
            'run_import_sap_import',
            // API Logs (Scoped - will be handled by Policy/Resource query, but needs permission to access the resource generally)
            'view_any_api_log',
            'view_api_log',
        ];

        // Ensure these permissions exist first (ApiLog might be new to this role)
        foreach ($allowed as $p) {
            Permission::firstOrCreate(['name' => $p, 'guard_name' => 'web']);
        }

        // 3. Sync Permissions (This removes everything else)
        $role->syncPermissions($allowed);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No real down needed, as we are defining the desired state.
    }
};
