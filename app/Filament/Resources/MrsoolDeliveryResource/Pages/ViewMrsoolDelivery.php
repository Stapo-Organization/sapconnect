<?php

namespace App\Filament\Resources\MrsoolDeliveryResource\Pages;

use App\Filament\Resources\MrsoolDeliveryResource;
use Filament\Resources\Pages\ViewRecord;

class ViewMrsoolDelivery extends ViewRecord
{
    protected static string $resource = MrsoolDeliveryResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
