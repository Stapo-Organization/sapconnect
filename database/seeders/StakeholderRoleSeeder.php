<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class StakeholderRoleSeeder extends Seeder
{
    /**
     * Seed the Stakeholder role with view-only permissions.
     *
     * Stakeholders (owners) can view all data across the platform
     * but cannot perform any mutating actions.
     */
    public function run(): void
    {
        // Create the role if it doesn't exist
        $role = Role::firstOrCreate(['name' => 'Stakeholder', 'guard_name' => 'web']);

        // Assign all view-related permissions
        $viewPermissions = Permission::where('name', 'like', 'view_%')
            ->orWhere('name', 'like', 'view_any_%')
            ->pluck('name')
            ->toArray();

        if (!empty($viewPermissions)) {
            $role->syncPermissions($viewPermissions);
            $this->command->info("Stakeholder role created/updated with " . count($viewPermissions) . " view-only permissions.");
        } else {
            $this->command->warn("No view permissions found. You may need to seed permissions first.");
        }

        $this->command->info("Stakeholder role is ready. Assign it to owner accounts via the Users admin page.");
    }
}
