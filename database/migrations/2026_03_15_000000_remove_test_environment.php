<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Update automations to Production DB
        DB::table('automations')
            ->where('sap_database', 'TEST_RETAIL01')
            ->update([
                'sap_database' => 'PPTC_V5_PROD'
            ]);

        // Fix command signatures by replacing TEST_RETAIL01 with PPTC_V5_PROD
        DB::table('automations')->get()->each(function ($automation) {
            $newCode = str_replace('TEST_RETAIL01', 'PPTC_V5_PROD', $automation->code);
            $newCommandSignature = str_replace('TEST_RETAIL01', 'PPTC_V5_PROD', $automation->command_signature);
            $newName = str_replace('TEST_RETAIL01', 'PPTC_V5_PROD', $automation->name);

            DB::table('automations')->where('id', $automation->id)->update([
                'code' => $newCode,
                'command_signature' => $newCommandSignature,
                'name' => $newName
            ]);
        });

        // 2. Remove default_environment from MobileAppSettings
        DB::table('mobile_app_settings')
            ->where('key', 'default_environment')
            ->delete();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Not reversible
    }
};
