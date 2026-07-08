<?php

namespace App\Filament\Resources\RegistrationPriorityResource\Pages;

use App\Filament\Resources\RegistrationPriorityResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListRegistrationPriorities extends ListRecords
{
    protected static string $resource = RegistrationPriorityResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
