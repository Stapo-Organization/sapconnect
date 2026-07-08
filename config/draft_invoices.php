<?php

return [
    /*
     | Absolute path to the PHP **CLI** binary used to spawn the background
     | `sap:draft-invoices` worker from the web UI. Under PHP-FPM, PHP_BINARY is
     | the FPM binary (cannot run artisan), so this must point at the CLI php.
     | On this cPanel host /usr/local/bin/php is the EA-PHP CLI symlink.
     */
    'php_binary' => env('DRAFT_INVOICES_PHP_BINARY', '/usr/local/bin/php'),

    // Default SAP company DB for the importer form.
    'default_db' => env('DRAFT_INVOICES_DB', 'PPTC_V5_PROD'),

    // Default freight expense code (SAP Additional Expense) pre-filled in the form.
    'default_expense_code' => env('DRAFT_INVOICES_EXPENSE_CODE', 1),

    /*
     | Fallback UoM AbsEntry for document lines = the base inventory unit
     | "PC / حبة" (AbsEntry 58 in PPTC_V5_PROD, UoM group 3). The lines force
     | this so quantities/prices are per-piece, NOT per the item's default
     | sales carton (which would multiply the quantity). Per-item
     | InventoryUoMEntry is used when available; this is the fallback.
     */
    'uom_entry' => env('DRAFT_INVOICES_UOM_ENTRY', 58),
];
