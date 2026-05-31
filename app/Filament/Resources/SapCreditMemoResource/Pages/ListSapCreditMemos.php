<?php

namespace App\Filament\Resources\SapCreditMemoResource\Pages;

use App\Filament\Resources\SapCreditMemoResource;
use Filament\Resources\Pages\ListRecords;

class ListSapCreditMemos extends ListRecords
{
    protected static string $resource = SapCreditMemoResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }
}
