<?php

namespace App\Filament\Resources\ApiLogResource\Pages;

use App\Filament\Resources\ApiLogResource;
use Filament\Resources\Pages\ListRecords;

class ListApiLogs extends ListRecords
{
    protected static string $resource = ApiLogResource::class;

    // Auto-refresh every 5 seconds to show live logs
    protected function getHeaderWidgets(): array
    {
        return [
            // We could put stats here
        ];
    }
}
