<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('token', 512)->unique();
            $table->string('platform', 16)->nullable(); // ios | android
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
        });

        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->timestamp('last_reminded_at')->nullable()->after('completed_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
        Schema::table('inventory_countings', function (Blueprint $table) {
            $table->dropColumn('last_reminded_at');
        });
    }
};
