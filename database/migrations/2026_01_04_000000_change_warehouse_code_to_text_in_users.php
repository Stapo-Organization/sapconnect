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
        Schema::table('users', function (Blueprint $table) {
            // Change warehouse_code to json (or text if json not supported, but json is standard)
            // Using text is safer sometimes if mariaDB version issues, but let's try json.
            // If it was string, we might need to drop and re-add or change.
            // Safe bet for existing data: keep as string but ideally it should handle JSON.
            // Let's assume user wants to keep data. If current is 'WH1', it will be invalid JSON.
            // We might need to convert existing values.

            // For this environment, let's just change it to nullable text/json.
            $table->text('warehouse_code')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('warehouse_code')->nullable()->change();
        });
    }
};
