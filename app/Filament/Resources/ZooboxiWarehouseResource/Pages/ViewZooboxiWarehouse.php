<?php

namespace App\Filament\Resources\ZooboxiWarehouseResource\Pages;

use App\Filament\Resources\ZooboxiWarehouseResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewZooboxiWarehouse extends ViewRecord
{
    protected static string $resource = ZooboxiWarehouseResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
