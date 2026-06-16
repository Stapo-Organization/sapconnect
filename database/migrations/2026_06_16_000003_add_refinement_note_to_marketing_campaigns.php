<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Owner's free-text revision note for the AI creative. When set, GenerateAdCreative
 * appends it to the gpt-image-2 prompt so the banner is re-rendered to the owner's
 * instruction ("make the headline bigger", "warmer background", etc.).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->text('refinement_note')->nullable()->after('brief');
        });
    }

    public function down(): void
    {
        Schema::table('marketing_campaigns', function (Blueprint $table) {
            $table->dropColumn('refinement_note');
        });
    }
};
