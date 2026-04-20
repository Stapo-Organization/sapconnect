<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->string('u_portal_sync')->nullable();
            $table->string('u_proprt1')->nullable();
            $table->string('u_proprt2')->nullable();
            $table->string('u_proprt3')->nullable();
            $table->string('u_proprt4')->nullable();
            $table->string('u_proprt5')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn([
                'u_portal_sync',
                'u_proprt1',
                'u_proprt2',
                'u_proprt3',
                'u_proprt4',
                'u_proprt5',
            ]);
        });
    }
};
