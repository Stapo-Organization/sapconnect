<?php

namespace App\Services\ShipGo;

use App\Models\MuntajatCustomer;

/**
 * READ-ONLY customers + statements of the main company (PPTC_V5_PROD).
 * Same behaviour as ShipGoSapService; only the company, mirror table and
 * branding differ. Service Layer GET only.
 */
class MuntajatSapService extends ShipGoSapService
{
    public function companyDb(): string
    {
        return (string) config('sap.muntajat_company_db', 'PPTC_V5_PROD');
    }

    public function configKey(): string
    {
        return 'muntajat';
    }

    public function customerModel(): string
    {
        return MuntajatCustomer::class;
    }

    public function invoiceModel(): string
    {
        return \App\Models\MuntajatInvoice::class;
    }
}
