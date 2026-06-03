<?php

namespace App\Filament\Resources\QualityTaskResource\Pages;

use App\Filament\Resources\QualityTaskResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditQualityTask extends EditRecord
{
    protected static string $resource = QualityTaskResource::class;

    protected function mutateFormDataBeforeSave(array $data): array
    {
        return QualityTaskResource::normalizeData($data);
    }

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
