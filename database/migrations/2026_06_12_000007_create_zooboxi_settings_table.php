<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Simple key/value store for owner-tunable Zooboxi intelligence settings
 * (e.g. the composite ranking weights read by intelligence:build-products).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('zooboxi_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->timestamps();
        });

        $now = now();
        $defaults = [
            'rank_w_avail' => '0.30',
            'rank_w_pop' => '0.26',
            'rank_w_margin' => '0.14',
            'rank_w_clearance' => '0.24',
            'rank_w_freshness' => '0.06',
        ];
        foreach ($defaults as $k => $v) {
            DB::table('zooboxi_settings')->insertOrIgnore([
                'key' => $k, 'value' => $v, 'created_at' => $now, 'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('zooboxi_settings');
    }
};
