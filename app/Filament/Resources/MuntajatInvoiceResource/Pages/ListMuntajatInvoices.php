<?php

namespace App\Filament\Resources\MuntajatInvoiceResource\Pages;

use App\Filament\Resources\MuntajatInvoiceResource;
use App\Filament\Resources\ShipGoInvoiceResource\Pages\ListShipGoInvoices;

class ListMuntajatInvoices extends ListShipGoInvoices
{
    protected static string $resource = MuntajatInvoiceResource::class;
}
