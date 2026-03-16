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
        Schema::create('api_transformers', function (Blueprint $table) {
            $table->id();
            $table->string('name')->comment('View name, e.g. Mobile');
            $table->string('resource')->comment('SAP Resource, e.g. Items');
            $table->json('mapping')->nullable()->comment('Field mapping configuration');
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            // Unique combination to prevent duplicates
            $table->unique(['resource', 'name']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('api_transformers');
    }
};
