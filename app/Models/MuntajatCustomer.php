<?php

namespace App\Models;

/**
 * Read-only mirror of a main-company (PPTC_V5_PROD) customer. Same shape as
 * ShipGoCustomer; refreshed by `muntajat:sync-customers`.
 */
class MuntajatCustomer extends ShipGoCustomer
{
    protected $table = 'muntajat_customers';
}
