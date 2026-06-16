<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Campaign attribution fixes:
 *  - event_type: enum -> string so a real 'click' value can be captured
 *    distinctly from organic 'view' (auditor fix H1). Validation stays app-level.
 *  - composite index on (zone, ab_variant, occurred_at) for the performance
 *    rollup GROUP BY (auditor fix A6) — store_events is the fastest-growing table.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('store_events', function (Blueprint $table) {
            $table->string('event_type')->change();
            $table->index(['zone', 'ab_variant', 'occurred_at'], 'store_events_campaign_idx');
        });
    }

    public function down(): void
    {
        Schema::table('store_events', function (Blueprint $table) {
            $table->dropIndex('store_events_campaign_idx');
            // event_type intentionally left as string on rollback (enum recreation is lossy)
        });
    }
};
