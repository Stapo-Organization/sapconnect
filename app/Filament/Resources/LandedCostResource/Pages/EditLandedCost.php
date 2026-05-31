<?php
namespace App\Filament\Resources\LandedCostResource\Pages;

use App\Filament\Resources\LandedCostResource;
use Filament\Resources\Pages\EditRecord;
use Filament\Actions;

class EditLandedCost extends EditRecord
{
    protected static string $resource = LandedCostResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('calculate')
                ->label('🔄 Recalculate All')
                ->icon('heroicon-o-calculator')
                ->color('warning')
                ->requiresConfirmation()
                ->action(function () {
                    $calculator = new \App\Services\LandedCostCalculator();
                    $calculator->calculate($this->record);

                    \Filament\Notifications\Notification::make()
                        ->title('Calculation Complete')
                        ->body("All {$this->record->lines()->count()} lines recalculated successfully.")
                        ->success()
                        ->send();

                    $this->fillForm();
                }),

            Actions\Action::make('import_po')
                ->label('📥 Import from PO')
                ->icon('heroicon-o-arrow-down-tray')
                ->color('info')
                ->requiresConfirmation()
                ->modalDescription('This will import all line items from the linked Purchase Order. Existing lines will be updated.')
                ->action(function () {
                    $calculator = new \App\Services\LandedCostCalculator();
                    $count = $calculator->importFromPurchaseOrder($this->record);

                    \Filament\Notifications\Notification::make()
                        ->title('Import Complete')
                        ->body("{$count} lines imported from PO #{$this->record->purchaseOrder?->po_number}.")
                        ->success()
                        ->send();

                    $this->fillForm();
                }),

            Actions\DeleteAction::make(),
        ];
    }
}
