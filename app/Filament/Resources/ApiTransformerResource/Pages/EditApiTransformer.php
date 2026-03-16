<?php

namespace App\Filament\Resources\ApiTransformerResource\Pages;

use App\Filament\Resources\ApiTransformerResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditApiTransformer extends EditRecord
{
    protected static string $resource = ApiTransformerResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
