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
            Actions\Action::make('draft_invoices')
                ->label('مسودات فواتير من تقرير مبيعات')
                ->icon('heroicon-o-document-currency-dollar')
                ->color('success')
                ->visible(fn () => \App\Filament\Resources\DraftInvoiceImportResource::canViewAny())
                ->url(fn () => \App\Filament\Resources\DraftInvoiceImportResource::getUrl()),
        ];
    }

    protected function getHeaderWidgets(): array
    {
        return [
            \App\Filament\Resources\SapImportResource\Widgets\SapStatusWidget::class,
        ];
    }
}
