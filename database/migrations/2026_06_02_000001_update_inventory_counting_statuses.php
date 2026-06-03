<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // For MySQL: modify the enum column to include new values first
        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            // Step 1: Alter the enum to include all new values
            DB::statement("ALTER TABLE inventory_countings MODIFY COLUMN status ENUM('draft', 'in_progress', 'completed', 'cancelled') DEFAULT 'in_progress'");

            // Step 2: Migrate existing 'draft' rows to 'in_progress'
            DB::table('inventory_countings')
                ->where('status', 'draft')
                ->update(['status' => 'in_progress']);

            // Step 3: Remove 'draft' from the enum (optional, keep for safety)
            DB::statement("ALTER TABLE inventory_countings MODIFY COLUMN status ENUM('in_progress', 'completed', 'cancelled') DEFAULT 'in_progress'");
        } else {
            // SQLite: column is text, just update values
            DB::table('inventory_countings')
                ->where('status', 'draft')
                ->update(['status' => 'in_progress']);
        }
    }

    public function down(): void
    {
        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            DB::statement("ALTER TABLE inventory_countings MODIFY COLUMN status ENUM('draft', 'in_progress', 'completed', 'cancelled') DEFAULT 'draft'");

            DB::table('inventory_countings')
                ->where('status', 'in_progress')
                ->update(['status' => 'draft']);

            DB::table('inventory_countings')
                ->where('status', 'cancelled')
                ->update(['status' => 'draft']);

            DB::statement("ALTER TABLE inventory_countings MODIFY COLUMN status ENUM('draft', 'completed') DEFAULT 'draft'");
        } else {
            DB::table('inventory_countings')
                ->where('status', 'in_progress')
                ->update(['status' => 'draft']);

            DB::table('inventory_countings')
                ->where('status', 'cancelled')
                ->update(['status' => 'draft']);
        }
    }
};
