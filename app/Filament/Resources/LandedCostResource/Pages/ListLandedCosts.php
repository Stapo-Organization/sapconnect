<?php
namespace App\Filament\Resources\LandedCostResource\Pages;
use App\Filament\Resources\LandedCostResource;
use Filament\Resources\Pages\ListRecords;
class ListLandedCosts extends ListRecords
{
    protected static string $resource = LandedCostResource::class;
    protected function getHeaderActions(): array
    {
        return [\Filament\Actions\CreateAction::make()];
    }
}
