<?php

namespace App\Filament\Resources\ZooboxiProductResource\Pages;

use App\Filament\Resources\ZooboxiProductResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewZooboxiProduct extends ViewRecord
{
    protected static string $resource = ZooboxiProductResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
