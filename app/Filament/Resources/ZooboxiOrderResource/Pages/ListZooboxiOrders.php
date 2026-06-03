<?php

namespace App\Filament\Resources\ZooboxiOrderResource\Pages;

use App\Filament\Resources\ZooboxiOrderResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Filament\Resources\Components\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListZooboxiOrders extends ListRecords
{
    protected static string $resource = ZooboxiOrderResource::class;

    protected function getHeaderActions(): array
    {
        return [];
    }

    public function getTabs(): array
    {
        return [
            'all' => Tab::make(__('All Orders'))
                ->icon('heroicon-o-squares-2x2')
                ->badge(fn () => \App\Models\ZooboxiOrder::count()),

            'pending' => Tab::make(__('Pending'))
                ->icon('heroicon-o-clock')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('delivery_status', 'pending'))
                ->badge(fn () => \App\Models\ZooboxiOrder::where('delivery_status', 'pending')->count())
                ->badgeColor('warning'),

            'preparing' => Tab::make(__('Preparing'))
                ->icon('heroicon-o-cog-6-tooth')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('delivery_status', 'preparing'))
                ->badge(fn () => \App\Models\ZooboxiOrder::where('delivery_status', 'preparing')->count())
                ->badgeColor('info'),

            'delivered' => Tab::make(__('Delivered'))
                ->icon('heroicon-o-check-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('delivery_status', 'delivered'))
                ->badge(fn () => \App\Models\ZooboxiOrder::where('delivery_status', 'delivered')->count())
                ->badgeColor('success'),

            'cancelled' => Tab::make(__('Cancelled'))
                ->icon('heroicon-o-x-circle')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('delivery_status', 'cancelled'))
                ->badge(fn () => \App\Models\ZooboxiOrder::where('delivery_status', 'cancelled')->count())
                ->badgeColor('danger'),
        ];
    }
}
