<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class ShowroomRoleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Create the role if it doesn't exist
        $role = Role::firstOrCreate(['name' => 'showroom']);

        // Ideally, we'd assign specific permissions here if we were using 
        // granular permissions (e.g., 'view stock_transfers').
        // For now, the role itself acts as the pivot for logic references.
    }
}
