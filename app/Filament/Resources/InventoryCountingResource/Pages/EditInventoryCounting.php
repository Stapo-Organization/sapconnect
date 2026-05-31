<?php

namespace App\Filament\Resources\InventoryCountingResource\Pages;

use App\Filament\Resources\InventoryCountingResource;
use Filament\Resources\Pages\EditRecord;

class EditInventoryCounting extends EditRecord
{
    protected static string $resource = InventoryCountingResource::class;

    protected static string $view = 'filament.resources.inventory-counting.edit';

    public function mount(int|string $record): void
    {
        parent::mount($record);

        // Prevent editing completed counts
        if ($this->record->isCompleted()) {
            $this->redirect($this->getResource()::getUrl('view', ['record' => $this->record]));
        }
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('view', ['record' => $this->record]);
    }
}
