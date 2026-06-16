<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * استثناءات صلاحيات خصائص التطبيق لكل مستخدم.
 * كل سطر = تجاوز يدوي فوق افتراضي الدور:
 *   effect = allow  → امنح هذه القدرة حتى لو لم يمنحها الدور.
 *   effect = deny   → امنع هذه القدرة حتى لو منحها الدور.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_feature_overrides', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('ability'); // مثال: stock_transfer.confirm_receive
            $table->enum('effect', ['allow', 'deny']);
            $table->timestamps();

            $table->unique(['user_id', 'ability']);
            $table->index('ability');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_feature_overrides');
    }
};
