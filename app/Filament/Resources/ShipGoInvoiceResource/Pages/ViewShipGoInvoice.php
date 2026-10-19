<?php

namespace App\Filament\Resources\ShipGoInvoiceResource\Pages;

use App\Filament\Resources\ShipGoInvoiceResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewShipGoInvoice extends ViewRecord
{
    protected static string $resource = ShipGoInvoiceResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('pdf')
                ->label(__('Invoice PDF'))
                ->icon('heroicon-o-printer')
                ->color('primary')
                ->url(fn () => static::getResource()::pdfUrl($this->record))
                ->openUrlInNewTab(),
        ];
    }
}
