<?php

namespace App\Filament\Resources\QualityTaskResource\Pages;

use App\Filament\Resources\QualityTaskResource;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;

class CreateQualityTask extends CreateRecord
{
    protected static string $resource = QualityTaskResource::class;

    /**
     * Fan out one form submission into one quality task per selected warehouse.
     */
    protected function handleRecordCreation(array $data): Model
    {
        $data = QualityTaskResource::normalizeData($data);

        $warehouseCodes = $data['warehouse_codes'] ?? [];
        unset($data['warehouse_codes']);

        if (empty($warehouseCodes) && !empty($data['warehouse_code'])) {
            $warehouseCodes = [$data['warehouse_code']];
        }

        $first = null;
        foreach ($warehouseCodes as $code) {
            $record = static::getModel()::create(array_merge($data, [
                'warehouse_code' => $code,
                'created_by' => auth()->id(),
            ]));
            $first ??= $record;
        }

        if (count($warehouseCodes) > 1) {
            Notification::make()
                ->title(__('Tasks created'))
                ->body(__(':count quality tasks were created — one per branch.', ['count' => count($warehouseCodes)]))
                ->success()
                ->send();
        }

        return $first;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
