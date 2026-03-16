<?php

namespace App\Filament\Resources\SapImportResource\Pages;

use App\Filament\Resources\SapImportResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditSapImport extends EditRecord
{
    protected static string $resource = SapImportResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
