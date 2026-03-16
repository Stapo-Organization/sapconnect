<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('zid_stores', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('store_id');
            $table->text('x_manager_token')->nullable();
            $table->text('authorization_token')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('zid_stores');
    }
};
