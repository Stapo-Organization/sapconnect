<?php

namespace App\Filament\Resources\InventoryCountingResource\Pages;

use App\Filament\Resources\InventoryCountingResource;
use Filament\Resources\Pages\ListRecords;

class ListInventoryCountings extends ListRecords
{
    protected static string $resource = InventoryCountingResource::class;

    protected function getHeaderActions(): array
    {
        return [
            \Filament\Actions\CreateAction::make(),
        ];
    }
}
