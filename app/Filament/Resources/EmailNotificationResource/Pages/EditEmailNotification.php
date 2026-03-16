<?php

namespace App\Filament\Resources\EmailNotificationResource\Pages;

use App\Filament\Resources\EmailNotificationResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditEmailNotification extends EditRecord
{
    protected static string $resource = EmailNotificationResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
