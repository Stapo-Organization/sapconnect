<?php

namespace App\Filament\Resources\EmailNotificationResource\Pages;

use App\Filament\Resources\EmailNotificationResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListEmailNotifications extends ListRecords
{
    protected static string $resource = EmailNotificationResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
