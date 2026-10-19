<?php

namespace App\Console\Commands;

use App\Services\ShipGo\MuntajatSapService;
use App\Services\ShipGo\ShipGoSapService;

/**
 * Mirrors the main company's (PPTC_V5_PROD) customers into `muntajat_customers`.
 * READ-ONLY toward SAP (Service Layer GET only).
 */
class SyncMuntajatCustomers extends SyncShipGoCustomers
{
    protected $signature   = 'muntajat:sync-customers';
    protected $description = 'Sync Muntajat (PPTC_V5_PROD) customers from SAP into the local mirror (read-only)';

    protected function service(): ShipGoSapService
    {
        return app(MuntajatSapService::class);
    }

    protected function label(): string
    {
        return 'Muntajat';
    }
}
