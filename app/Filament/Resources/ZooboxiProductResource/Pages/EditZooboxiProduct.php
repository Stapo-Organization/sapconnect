<?php

namespace App\Filament\Resources\ZooboxiProductResource\Pages;

use App\Filament\Resources\ZooboxiProductResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditZooboxiProduct extends EditRecord
{
    protected static string $resource = ZooboxiProductResource::class;

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
