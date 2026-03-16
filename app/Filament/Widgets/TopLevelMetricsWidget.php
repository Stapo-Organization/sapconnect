<?php

namespace App\Filament\Widgets;

use App\Models\Product;
use App\Models\StockTransfer;
use App\Models\Warehouse;
use App\Models\Brand;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class TopLevelMetricsWidget extends BaseWidget
{
    // Make sure this widget spans the full width of the dashboard at the very top.
    protected int | string | array $columnSpan = 'full';
    
    // Sort position: prioritize it to the top.
    protected static ?int $sort = 1;

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected function getStats(): array
    {
        $brandDate = \App\Models\Brand::max('updated_at');
        $brandDesc = __('Brands imported from SAP') . ($brandDate ? ' - ' . \Carbon\Carbon::parse($brandDate)->format('Y-m-d H:i') : '');

        $productDate = \App\Models\Product::max('updated_at');
        $productDesc = __('Products imported from SAP') . ($productDate ? ' - ' . \Carbon\Carbon::parse($productDate)->format('Y-m-d H:i') : '');

        $warehouseDate = \App\Models\Warehouse::max('updated_at');
        $warehouseDesc = __('Registered in SAP') . ($warehouseDate ? ' - ' . \Carbon\Carbon::parse($warehouseDate)->format('Y-m-d H:i') : '');

        $transferDate = \App\Models\StockTransfer::max('updated_at');
        $transferDesc = __('All Time Requests') . ($transferDate ? ' - ' . \Carbon\Carbon::parse($transferDate)->format('Y-m-d H:i') : '');

        return [
            Stat::make(__('Total Synced Brands'), Brand::count())
                ->description($brandDesc)
                ->descriptionIcon('heroicon-m-tag')
                ->color('warning')
                ->url(route('filament.admin.resources.brands.index')),

            Stat::make(__('Total Synced Products'), Product::count())
                ->description($productDesc)
                ->descriptionIcon('heroicon-m-cube')
                ->color('primary')
                ->url(route('filament.admin.resources.products.index')),
                
            Stat::make(__('Active Warehouses'), Warehouse::count())
                ->description($warehouseDesc)
                ->descriptionIcon('heroicon-m-building-storefront')
                ->color('success')
                ->url(route('filament.admin.resources.warehouses.index')),
                
            Stat::make(__('Total Stock Transfers'), StockTransfer::count())
                ->description($transferDesc)
                ->descriptionIcon('heroicon-m-truck')
                ->color('info')
                ->url(route('filament.admin.resources.stock-transfers.index')),
        ];
    }
}
