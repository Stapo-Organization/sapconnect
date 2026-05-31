<?php

namespace App\Filament\Resources\ForwarderResource\Pages;

use App\Filament\Resources\ForwarderResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditForwarder extends EditRecord
{
    protected static string $resource = ForwarderResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
