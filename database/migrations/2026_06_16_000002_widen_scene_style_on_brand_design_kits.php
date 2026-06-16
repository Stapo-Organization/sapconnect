<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * scene_style was created as VARCHAR(255) but researched art-direction lines run
 * longer (up to ~400 chars). Widen to TEXT. MySQL enforces VARCHAR length (prod
 * threw "Data too long"); sqlite does not, so this is a no-op there.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE brand_design_kits MODIFY scene_style TEXT NULL');
        }
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE brand_design_kits MODIFY scene_style VARCHAR(255) NULL');
        }
    }
};
