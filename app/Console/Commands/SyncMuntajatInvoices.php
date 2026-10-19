<?php

namespace App\Console\Commands;

use App\Services\ShipGo\MuntajatSapService;
use App\Services\ShipGo\ShipGoSapService;

/** Mirrors A/R invoice headers of the main company (PPTC_V5_PROD), retail excluded. */
class SyncMuntajatInvoices extends SyncShipGoInvoices
{
    protected $signature   = 'muntajat:sync-invoices {--full : Re-read every invoice instead of recent changes}';
    protected $description = 'Sync Muntajat (PPTC_V5_PROD) A/R invoice headers from SAP (read-only)';

    protected function service(): ShipGoSapService
    {
        return app(MuntajatSapService::class);
    }

    protected function label(): string
    {
        return 'Muntajat';
    }
}
