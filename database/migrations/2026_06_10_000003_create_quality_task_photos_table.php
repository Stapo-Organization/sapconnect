<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('quality_task_photos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quality_task_instance_id')->constrained('quality_task_instances')->cascadeOnDelete();
            $table->string('checklist_item_key')->nullable(); // null = general (min-N) photo
            $table->string('disk')->default('public');
            $table->string('path');
            $table->string('original_name')->nullable();
            $table->unsignedInteger('size')->nullable(); // bytes
            $table->unsignedBigInteger('uploaded_by')->nullable();
            $table->timestamps();

            $table->index('checklist_item_key');
            $table->foreign('uploaded_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quality_task_photos');
    }
};
