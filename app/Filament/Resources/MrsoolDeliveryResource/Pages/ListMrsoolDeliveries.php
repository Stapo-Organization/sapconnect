<?php

namespace App\Filament\Resources\MrsoolDeliveryResource\Pages;

use App\Filament\Resources\MrsoolDeliveryResource;
use Filament\Resources\Pages\ListRecords;

class ListMrsoolDeliveries extends ListRecords
{
    protected static string $resource = MrsoolDeliveryResource::class;

    protected function getHeaderActions(): array
    {
        return []; // Read-only: deliveries are created from the branch app.
    }
}
