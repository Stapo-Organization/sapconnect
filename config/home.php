<?php

/*
|--------------------------------------------------------------------------
| Home Dashboard — Smart Priority Feed
|--------------------------------------------------------------------------
|
| Tunable weights for the deterministic urgency-scoring model that powers
| the "Action Center" on the exhibition-manager home screen
| (App\Services\Home\HomeFeedBuilder). Adjust here without touching code.
|
*/

return [

    // Max number of items surfaced in the Action Center feed.
    'feed_limit' => 8,

    // Base priority by item type (higher = more urgent).
    'base' => [
        'zooboxi_order'   => 100,
        'overdue_cycle'   => 90,
        'overdue_quality' => 85,
        'due_quality'     => 60,
        'pending_receive' => 55,
        'pending_send'    => 50,
        'due_cycle'       => 45,
        'promo_approval'  => 40,
    ],

    // Aging bonuses (added on top of the base score).
    'aging' => [
        // Zooboxi: + minutes * factor, capped at the SLA window.
        'zooboxi_sla_minutes' => 240,   // 4h hard SLA
        'zooboxi_factor'      => 0.5,   // +120 max at breach

        // Overdue cycle/quality: + daysOverdue * factor, capped.
        'overdue_days_cap'    => 30,
        'overdue_factor'      => 3,     // +90 max

        // Transfers backlog nudge: + min(count, cap).
        'transfer_count_cap'  => 10,
    ],

    // SLA bands for Zooboxi orders (minutes since created).
    'zooboxi_bands' => [
        'critical' => 30,   // > 30 min  → critical
        'warning'  => 15,   // 15–30 min → warning
    ],

    // How far ahead an upcoming cycle count counts as "due soon" (days).
    'due_cycle_window_days' => 1,
];
