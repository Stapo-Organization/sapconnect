<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Structured rejection feedback: a coarse category (copy/design/image/product/
 * offer/identity/other) alongside the existing free-text `rejected_reason`. Lets
 * us aggregate WHY creatives get rejected and feed that back into the generator.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->string('rejected_category')->nullable()->after('rejected_reason');
        });
    }

    public function down(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->dropColumn('rejected_category');
        });
    }
};
