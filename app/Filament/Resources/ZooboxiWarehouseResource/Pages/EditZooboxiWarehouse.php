<?php

namespace App\Filament\Resources\ZooboxiWarehouseResource\Pages;

use App\Filament\Resources\ZooboxiWarehouseResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditZooboxiWarehouse extends EditRecord
{
    protected static string $resource = ZooboxiWarehouseResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('view', ['record' => $this->getRecord()]);
    }
}
