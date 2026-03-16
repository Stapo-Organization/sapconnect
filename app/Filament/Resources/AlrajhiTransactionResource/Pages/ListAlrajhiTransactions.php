<?php

namespace App\Filament\Resources\AlrajhiTransactionResource\Pages;

use App\Filament\Resources\AlrajhiTransactionResource;
use Filament\Resources\Pages\ListRecords;

class ListAlrajhiTransactions extends ListRecords
{
    protected static string $resource = AlrajhiTransactionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            // Standard create action not needed
        ];
    }
}
