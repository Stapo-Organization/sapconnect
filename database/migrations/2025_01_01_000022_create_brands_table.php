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
        Schema::create('brands', function (Blueprint $table) {
            $table->id();
            $table->string('code')->index(); // SAP Number
            $table->string('name'); // SAP GroupName
            $table->string('source')->index(); // 'test' or 'production'
            $table->timestamps();

            $table->unique(['code', 'source']); // Unique constraint per environment
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('brands');
    }
};
