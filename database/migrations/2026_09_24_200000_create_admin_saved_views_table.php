<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Saved table views for the admin panel: a named snapshot of a list page's
     * URL state (filters, search, sort, tab, grouping) plus its visible columns.
     */
    public function up(): void
    {
        Schema::create('admin_saved_views', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('page_class');
            $table->string('name', 80);
            $table->text('query')->nullable();
            $table->json('columns')->nullable();
            $table->boolean('is_shared')->default(false);
            $table->boolean('is_pinned')->default(false);
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();

            $table->index(['page_class', 'user_id']);
            $table->index(['user_id', 'is_pinned']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_saved_views');
    }
};
