<?php

namespace App\Filament\Resources\QualityTaskResource\Pages;

use App\Filament\Resources\QualityTaskResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListQualityTasks extends ListRecords
{
    protected static string $resource = QualityTaskResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
