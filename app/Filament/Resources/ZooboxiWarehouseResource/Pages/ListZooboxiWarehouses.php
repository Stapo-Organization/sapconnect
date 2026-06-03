<?php

namespace App\Filament\Resources\ZooboxiWarehouseResource\Pages;

use App\Filament\Resources\ZooboxiWarehouseResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListZooboxiWarehouses extends ListRecords
{
    protected static string $resource = ZooboxiWarehouseResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
