<?php

namespace App\Filament\Resources\ZooboxiSyncLogResource\Pages;

use App\Filament\Resources\ZooboxiSyncLogResource;
use Filament\Resources\Pages\ListRecords;
use Filament\Resources\Components\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListZooboxiSyncLogs extends ListRecords
{
    protected static string $resource = ZooboxiSyncLogResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }

    public function getTabs(): array
    {
        return [
            'all' => Tab::make(__('All'))
                ->icon('heroicon-o-squares-2x2'),

            'completed' => Tab::make(__('Completed'))
                ->icon('heroicon-o-check-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'completed'))
                ->badgeColor('success'),

            'failed' => Tab::make(__('Failed'))
                ->icon('heroicon-o-x-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'failed'))
                ->badge(fn () => \App\Models\ZooboxiSyncLog::where('status', 'failed')->count())
                ->badgeColor('danger'),

            'running' => Tab::make(__('Running'))
                ->icon('heroicon-o-arrow-path')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'running'))
                ->badge(fn () => \App\Models\ZooboxiSyncLog::where('status', 'running')->count())
                ->badgeColor('warning'),
        ];
    }
}
