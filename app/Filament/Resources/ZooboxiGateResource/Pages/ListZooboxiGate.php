<?php

namespace App\Filament\Resources\ZooboxiGateResource\Pages;

use App\Filament\Resources\ZooboxiGateResource;
use App\Filament\Widgets\ZooboxiGateStatsWidget;
use App\Models\Product;
use Filament\Resources\Components\Tab;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Database\Eloquent\Builder;

class ListZooboxiGate extends ListRecords
{
    protected static string $resource = ZooboxiGateResource::class;

    protected function getHeaderWidgets(): array
    {
        return [ZooboxiGateStatsWidget::class];
    }

    public function getTabs(): array
    {
        $count = fn (string $status) => Product::production()->where('zooboxi_active', false)->where('zooboxi_gate_status', $status)->count();
        return [
            'held' => Tab::make('محجوز')
                ->icon('heroicon-o-hand-raised')
                ->modifyQueryUsing(fn (Builder $q) => $q->where('zooboxi_gate_status', 'held'))
                ->badge($count('held'))->badgeColor('warning'),
            'pending' => Tab::make('بانتظار الفحص')
                ->icon('heroicon-o-clock')
                ->modifyQueryUsing(fn (Builder $q) => $q->where('zooboxi_gate_status', 'pending'))
                ->badge($count('pending'))->badgeColor('gray'),
            'blocked' => Tab::make('محظور')
                ->icon('heroicon-o-no-symbol')
                ->modifyQueryUsing(fn (Builder $q) => $q->where('zooboxi_gate_status', 'blocked'))
                ->badge($count('blocked'))->badgeColor('danger'),
            'all' => Tab::make('الكل')->icon('heroicon-o-squares-2x2'),
        ];
    }
}
