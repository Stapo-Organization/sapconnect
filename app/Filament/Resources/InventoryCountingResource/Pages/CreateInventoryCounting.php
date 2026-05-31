<?php

namespace App\Filament\Resources\InventoryCountingResource\Pages;

use App\Filament\Resources\InventoryCountingResource;
use App\Models\InventoryCounting;
use App\Models\InventoryCountingLine;
use App\Models\Product;
use App\Models\Warehouse;
use Filament\Resources\Pages\CreateRecord;
use Filament\Notifications\Notification;

class CreateInventoryCounting extends CreateRecord
{
    protected static string $resource = InventoryCountingResource::class;

    public array $scannedItems = [];

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['counted_by'] = auth()->id();

        // Get warehouse name
        if (!empty($data['warehouse_code']) && empty($data['warehouse_name'])) {
            $warehouse = Warehouse::where('warehouse_code', $data['warehouse_code'])->first();
            $data['warehouse_name'] = $warehouse?->warehouse_name;
        }

        return $data;
    }

    protected function afterCreate(): void
    {
        // Save all scanned items as lines
        foreach ($this->scannedItems as $item) {
            $this->record->lines()->create([
                'item_code' => $item['item_code'],
                'item_name' => $item['item_name'],
                'piece_barcode' => $item['piece_barcode'] ?? null,
                'counted_quantity' => $item['counted_quantity'] ?? 0,
            ]);
        }
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('view', ['record' => $this->record]);
    }
}
