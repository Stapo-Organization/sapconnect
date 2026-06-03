<?php

namespace App\Filament\Resources\ZooboxiProductResource\Pages;

use App\Filament\Resources\ZooboxiProductResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Filament\Resources\Components\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListZooboxiProducts extends ListRecords
{
    protected static string $resource = ZooboxiProductResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }

    public function getTabs(): array
    {
        return [
            'woo_synced' => Tab::make(__('Synced to WC'))
                ->icon('heroicon-o-check-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('woo_sync', true))
                ->badge(fn () => \App\Models\Product::where('source', 'production')->where('woo_sync', true)->count()),

            'all' => Tab::make(__('All Products'))
                ->icon('heroicon-o-squares-2x2')
                ->badge(fn () => \App\Models\Product::where('source', 'production')->count()),

            'not_synced' => Tab::make(__('Not Synced'))
                ->icon('heroicon-o-x-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where(function ($q) {
                    $q->where('woo_sync', false)->orWhereNull('woo_sync');
                }))
                ->badge(fn () => \App\Models\Product::where('source', 'production')->where(function ($q) {
                    $q->where('woo_sync', false)->orWhereNull('woo_sync');
                })->count()),
        ];
    }

    public function getDefaultActiveTab(): string|int|null
    {
        return 'woo_synced';
    }
}
