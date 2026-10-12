<?php

namespace App\Filament\Resources\ShipGoCustomerResource\Pages;

use App\Filament\Resources\ShipGoCustomerResource;
use App\Models\ShipGoCustomer;
use App\Services\ShipGo\ShipGoSapService;
use Filament\Actions;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ViewRecord;

class ViewShipGoCustomer extends ViewRecord
{
    protected static string $resource = ShipGoCustomerResource::class;

    protected function getHeaderActions(): array
    {
        return [
            ShipGoCustomerResource::headerStatementAction(),
            Actions\Action::make('refresh')
                ->label(__('Refresh from SAP'))
                ->icon('heroicon-o-arrow-path')
                ->color('gray')
                ->action(function () {
                    try {
                        $bp = app(ShipGoSapService::class)->fetchCustomer($this->record->card_code);
                        if ($bp) {
                            $this->record->fill(ShipGoCustomer::attributesFromSap($bp))->save();
                            $this->refreshFormData(array_keys($this->record->getAttributes()));
                            Notification::make()->title(__('Customer refreshed from SAP'))->success()->send();
                        }
                    } catch (\Throwable $e) {
                        Notification::make()->title(__('Refresh failed'))->body($e->getMessage())->danger()->send();
                    }
                }),
        ];
    }
}
