<?php

namespace App\Filament\Resources\ApiTransformerResource\Pages;

use App\Filament\Resources\ApiTransformerResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListApiTransformers extends ListRecords
{
    protected static string $resource = ApiTransformerResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
