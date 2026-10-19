<?php

namespace App\Filament\Resources\ShipGoCustomerResource\Pages;

use App\Filament\Resources\ShipGoCustomerResource;
use App\Models\ShipGoCustomer;
use App\Services\ShipGo\ShipGoSapService;
use Filament\Actions;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;

class ListShipGoCustomers extends ListRecords
{
    protected static string $resource = ShipGoCustomerResource::class;

    public function getSubheading(): ?string
    {
        $model = static::getResource()::getModel();
        $last  = $model::max('synced_at');
        $db    = static::getResource()::sapService()->companyDb();

        return $last
            ? __('Source: :db · last sync :time', ['db' => $db, 'time' => \Carbon\Carbon::parse($last)->diffForHumans()])
            : __('Source: :db · not synced yet', ['db' => $db]);
    }

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('sync')
                ->label(__('Sync from SAP'))
                ->icon('heroicon-o-arrow-path')
                ->color('gray')
                ->requiresConfirmation()
                ->modalHeading(__('Sync from SAP'))
                ->modalDescription(__('Reads the customer list from :db. Nothing is written to SAP.', ['db' => static::getResource()::sapService()->companyDb()]))
                ->visible(fn () => auth()->user()?->hasAnyRole(['Super Admin', 'Finance', 'Operator', 'Accountant']))
                ->action(function () {
                    try {
                        @set_time_limit(600);
                        $r = static::getResource()::sapService()->syncCustomers();
                        Notification::make()
                            ->title(__('Sync complete'))
                            ->body(__(':total customers read — :created new, :updated updated.', $r))
                            ->success()
                            ->send();
                    } catch (\Throwable $e) {
                        Notification::make()
                            ->title(__('Sync failed'))
                            ->body($e->getMessage())
                            ->danger()
                            ->persistent()
                            ->send();
                    }
                }),
        ];
    }
}
