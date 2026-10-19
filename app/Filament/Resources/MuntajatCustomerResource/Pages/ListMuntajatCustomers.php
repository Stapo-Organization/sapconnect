<?php

namespace App\Filament\Resources\MuntajatCustomerResource\Pages;

use App\Filament\Resources\MuntajatCustomerResource;
use App\Filament\Resources\ShipGoCustomerResource\Pages\ListShipGoCustomers;

class ListMuntajatCustomers extends ListShipGoCustomers
{
    protected static string $resource = MuntajatCustomerResource::class;
}
