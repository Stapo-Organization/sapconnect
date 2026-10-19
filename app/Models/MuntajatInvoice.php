<?php

namespace App\Models;

/** Read-only mirror of a main-company (PPTC_V5_PROD) A/R invoice header. */
class MuntajatInvoice extends ShipGoInvoice
{
    protected $table = 'muntajat_invoices';

    protected static string $customerModel = MuntajatCustomer::class;
}
