<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Concerns\HandlesFeatureOverrides;
use App\Filament\Concerns\HandlesNotificationPreferences;
use App\Filament\Resources\UserResource;
use Filament\Resources\Pages\CreateRecord;

class CreateUser extends CreateRecord
{
    use HandlesFeatureOverrides;
    use HandlesNotificationPreferences;

    protected static string $resource = UserResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data = $this->extractFeatureOverrides($data);
        $data = $this->extractNotificationPrefs($data);
        return $data;
    }

    protected function afterCreate(): void
    {
        $this->persistFeatureOverrides($this->record);
        $this->persistNotificationPrefs($this->record);
    }
}
