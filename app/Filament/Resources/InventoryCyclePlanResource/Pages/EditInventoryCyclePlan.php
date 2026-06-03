<?php

namespace App\Filament\Resources\InventoryCyclePlanResource\Pages;

use App\Filament\Resources\InventoryCyclePlanResource;
use Filament\Resources\Pages\EditRecord;

class EditInventoryCyclePlan extends EditRecord
{
    protected static string $resource = InventoryCyclePlanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            \Filament\Actions\DeleteAction::make(),
        ];
    }
}
