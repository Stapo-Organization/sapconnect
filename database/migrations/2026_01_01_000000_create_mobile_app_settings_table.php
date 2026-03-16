<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('mobile_app_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->string('type')->default('string'); // string, boolean, integer, etc.
            $table->string('description')->nullable();
            $table->timestamps();
        });

        // Seed default keys
        DB::table('mobile_app_settings')->insertOrIgnore([
            [
                'key' => 'default_environment',
                'value' => 'production',
                'type' => 'string',
                'description' => 'Default API Environment for Mobile App (production/test)',
                'created_at' => now(),
                'updated_at' => now()
            ],
            [
                'key' => 'maintenance_mode',
                'value' => '0',
                'type' => 'boolean',
                'description' => 'Enable Maintenance Mode for Mobile App',
                'created_at' => now(),
                'updated_at' => now()
            ]
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('mobile_app_settings');
    }
};
