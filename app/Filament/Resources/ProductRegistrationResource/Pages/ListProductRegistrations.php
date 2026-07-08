<?php

namespace App\Filament\Resources\ProductRegistrationResource\Pages;

use App\Filament\Resources\ProductRegistrationResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListProductRegistrations extends ListRecords
{
    protected static string $resource = ProductRegistrationResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
