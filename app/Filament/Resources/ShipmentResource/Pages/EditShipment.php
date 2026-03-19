<?php

namespace App\Filament\Resources\ShipmentResource\Pages;

use App\Filament\Resources\ShipmentResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditShipment extends EditRecord
{
    protected static string $resource = ShipmentResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
    
    protected function mutateFormDataBeforeSave(array $data): array
    {
        // Calculate Total Freight Cost
        $total = 0;
        if (isset($data['containers']) && is_array($data['containers'])) {
            foreach ($data['containers'] as $container) {
                $total += (float) ($container['freight_cost'] ?? 0);
            }
        }
        $data['total_freight_cost'] = $total;
        
        return $data;
    }
}
