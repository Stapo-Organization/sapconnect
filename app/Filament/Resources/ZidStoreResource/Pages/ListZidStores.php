<?php

namespace App\Filament\Resources\ZidStoreResource\Pages;

use App\Filament\Resources\ZidStoreResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListZidStores extends ListRecords
{
    protected static string $resource = ZidStoreResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
