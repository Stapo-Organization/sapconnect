<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Concerns\HandlesFeatureOverrides;
use App\Filament\Concerns\HandlesNotificationPreferences;
use App\Filament\Resources\UserResource;
use Filament\Resources\Pages\EditRecord;
use Filament\Actions;

class EditUser extends EditRecord
{
    use HandlesFeatureOverrides;
    use HandlesNotificationPreferences;

    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeFill(array $data): array
    {
        $data = $this->loadFeatureOverrides($data, $this->record);
        $data = $this->loadNotificationPrefs($data, $this->record);
        return $data;
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data = $this->extractFeatureOverrides($data);
        $data = $this->extractNotificationPrefs($data);
        return $data;
    }

    protected function afterSave(): void
    {
        $this->persistFeatureOverrides($this->record);
        $this->persistNotificationPrefs($this->record);
    }
}
