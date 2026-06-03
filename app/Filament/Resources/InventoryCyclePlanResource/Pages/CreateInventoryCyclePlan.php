<?php

namespace App\Filament\Resources\InventoryCyclePlanResource\Pages;

use App\Filament\Resources\InventoryCyclePlanResource;
use App\Models\Warehouse;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;

class CreateInventoryCyclePlan extends CreateRecord
{
    protected static string $resource = InventoryCyclePlanResource::class;

    /**
     * Fan out a single form submission into one plan per selected warehouse.
     * Each plan operates independently (ABC counts, quotas and cycle progress
     * are inherently per-warehouse), but the configuration is filled only once.
     */
    protected function handleRecordCreation(array $data): Model
    {
        $warehouseCodes = $data['warehouse_codes'] ?? [];
        unset($data['warehouse_codes']);

        // Fallback safety: if somehow empty, keep any single warehouse_code already set.
        if (empty($warehouseCodes) && ! empty($data['warehouse_code'])) {
            $warehouseCodes = [$data['warehouse_code']];
        }

        $names = Warehouse::whereIn('warehouse_code', $warehouseCodes)
            ->pluck('warehouse_name', 'warehouse_code');

        $multiple = count($warehouseCodes) > 1;
        $baseName = $data['plan_name'];

        $first = null;

        foreach ($warehouseCodes as $code) {
            // Disambiguate plan names when several warehouses share one submission.
            $planName = $multiple
                ? trim($baseName) . ' — ' . ($names[$code] ?? $code)
                : $baseName;

            $record = static::getModel()::create(array_merge($data, [
                'warehouse_code' => $code,
                'plan_name' => $planName,
                'created_by' => auth()->id(),
            ]));

            $first ??= $record;
        }

        if ($multiple) {
            Notification::make()
                ->title(__('Plans created'))
                ->body(__(':count cycle plans were created — one per warehouse.', ['count' => count($warehouseCodes)]))
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
