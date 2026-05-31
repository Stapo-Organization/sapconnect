<?php
\App\Models\Automation::updateOrCreate(
    ['command_signature' => 'sap:sync-recent-invoices'],
    [
        'name' => 'Sync Recent Invoices',
        'code' => 'sync_recent_invoices',
        'is_active' => true,
        'schedule_frequency' => 'everyTenMinutes',
    ]
);
\App\Models\Automation::updateOrCreate(
    ['command_signature' => 'sap:sync-recent-stock'],
    [
        'name' => 'Sync Recent Stock',
        'code' => 'sync_recent_stock',
        'is_active' => true,
        'schedule_frequency' => 'everyTenMinutes',
    ]
);
echo "Automations created successfully!\n";
