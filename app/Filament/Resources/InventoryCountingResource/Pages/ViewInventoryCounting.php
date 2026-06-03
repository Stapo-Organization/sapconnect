<?php

namespace App\Filament\Resources\InventoryCountingResource\Pages;

use App\Filament\Resources\InventoryCountingResource;
use Filament\Resources\Pages\ViewRecord;
use Filament\Infolists\Infolist;
use Filament\Infolists\Components;

class ViewInventoryCounting extends ViewRecord
{
    protected static string $resource = InventoryCountingResource::class;

    protected static string $view = 'filament.resources.inventory-counting.view';

    protected function getHeaderActions(): array
    {
        return [
            \Filament\Actions\EditAction::make()
                ->visible(fn () => $this->record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager'])),
            \Filament\Actions\Action::make('complete')
                ->label(__('Mark as Completed'))
                ->icon('heroicon-o-check-circle')
                ->color('success')
                ->requiresConfirmation()
                ->visible(fn () => $this->record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager']))
                ->action(function () {
                    $this->record->markAsCompleted();
                    // Calculate variances
                    $service = new \App\Services\Counting\VarianceCalculationService();
                    $summary = $service->calculateForSession($this->record);
                    \Filament\Notifications\Notification::make()
                        ->title(__('Inventory count completed'))
                        ->body("Match: {$summary['match']} | Over: {$summary['over']} | Short: {$summary['short']}")
                        ->success()
                        ->send();
                    $this->redirect($this->getResource()::getUrl('view', ['record' => $this->record]));
                }),
        ];
    }
}
