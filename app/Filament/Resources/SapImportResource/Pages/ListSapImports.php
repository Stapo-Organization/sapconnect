<?php

namespace App\Filament\Resources\SapImportResource\Pages;

use App\Filament\Resources\SapImportResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListSapImports extends ListRecords
{
    protected static string $resource = SapImportResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    protected function getHeaderWidgets(): array
    {
        return [
            \App\Filament\Resources\SapImportResource\Widgets\SapStatusWidget::class,
        ];
    }
}
