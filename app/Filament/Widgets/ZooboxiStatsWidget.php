<?php

namespace App\Filament\Widgets;

use App\Models\Product;
use App\Models\ZooboxiWarehouse;
use App\Models\ZooboxiOrder;
use App\Models\ZooboxiSyncLog;
use App\Models\WarehouseItemStock;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Carbon\Carbon;

class ZooboxiStatsWidget extends BaseWidget
{
    protected int | string | array $columnSpan = 'full';

    protected static ?int $sort = 10;

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected function getStats(): array
    {
        // Zooboxi active products (have ZID data)
        $zoobixiActive = Product::where('zooboxi_active', true)->count();
        $withDescription = Product::where('zooboxi_active', true)
            ->whereNotNull('zb_description_ar')
            ->where('zb_description_ar', '!=', '')
            ->count();
        $withImages = Product::where('zooboxi_active', true)
            ->whereNotNull('zb_images')
            ->count();
        $activeDesc = __('With description') . ": {$withDescription} | " . __('With images') . ": {$withImages}";

        // Active warehouses
        $activeWarehouses = ZooboxiWarehouse::where('is_active', true)->count();
        $totalWarehouses = ZooboxiWarehouse::count();
        $warehouseDesc = $activeWarehouses . '/' . $totalWarehouses . ' ' . __('active');

        // Orders stats
        $pendingOrders = ZooboxiOrder::where('delivery_status', 'pending')->count();
        $totalOrders = ZooboxiOrder::count();
        $todayOrders = ZooboxiOrder::whereDate('created_at', Carbon::today())->count();
        $orderDesc = __('Today') . ': ' . $todayOrders . ' | ' . __('Pending') . ': ' . $pendingOrders;

        // Latest stock sync
        $lastStockSync = ZooboxiSyncLog::where('sync_type', 'stock')
            ->where('status', 'completed')
            ->latest('completed_at')
            ->first();
        $stockSyncDesc = $lastStockSync
            ? __('Last sync') . ': ' . $lastStockSync->completed_at->diffForHumans()
            : __('No sync yet');

        // Stock records count
        $stockRecords = WarehouseItemStock::count();
        $stockItemsUpdatedToday = WarehouseItemStock::whereDate('updated_at', Carbon::today())
            ->distinct('item_code')
            ->count('item_code');

        return [
            Stat::make('🛍️ ' . __('Zooboxi Products'), number_format($zoobixiActive))
                ->description($activeDesc)
                ->descriptionIcon('heroicon-m-shopping-bag')
                ->color('success')
                ->url(route('filament.admin.resources.zooboxi-products.index')),

            Stat::make('🏪 ' . __('Active Warehouses'), $activeWarehouses)
                ->description($warehouseDesc)
                ->descriptionIcon('heroicon-m-building-storefront')
                ->color('info')
                ->url(route('filament.admin.resources.zooboxi-warehouses.index')),

            Stat::make('📋 ' . __('Total Orders'), number_format($totalOrders))
                ->description($orderDesc)
                ->descriptionIcon('heroicon-m-shopping-cart')
                ->color($pendingOrders > 0 ? 'warning' : 'success')
                ->url(route('filament.admin.resources.zooboxi-orders.index')),

            Stat::make('📊 ' . __('Stock Records'), number_format($stockRecords))
                ->description(__('Updated today') . ': ' . number_format($stockItemsUpdatedToday) . ' items')
                ->descriptionIcon('heroicon-m-arrow-path-rounded-square')
                ->color('primary'),

            Stat::make('🔄 ' . __('Last Stock Sync'), $lastStockSync ? $lastStockSync->completed_at->format('H:i') : '-')
                ->description($stockSyncDesc)
                ->descriptionIcon('heroicon-m-clock')
                ->color($lastStockSync && $lastStockSync->completed_at->gt(now()->subHour()) ? 'success' : 'danger'),
        ];
    }
}
