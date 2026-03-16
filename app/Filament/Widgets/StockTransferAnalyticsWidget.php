<?php

namespace App\Filament\Widgets;

use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class StockTransferAnalyticsWidget extends BaseWidget
{
    protected static ?int $sort = 2; // Right below TopLevelMetrics

        protected function getStats(): array
    {
        // 1. Pending Actions (Shipped but not received, or New but not shipped)
        $baseQuery = \App\Filament\Resources\StockTransferResource::getEloquentQuery();
        
        $pendingActionsQuery = (clone $baseQuery)->whereIn('internal_status', [
            StockTransfer::STATUS_NEW,
            StockTransfer::STATUS_SHIPPED
        ]);
        $pendingActions = (clone $pendingActionsQuery)->count();

        // 2. Overdue Transfers (Open transfers > 1 week: New or Shipped)
        $overdueCount = (clone $pendingActionsQuery)
            ->where('doc_date', '<', Carbon::now()->subDays(7))
            ->count();

        // 3. Total Units Shipped vs Received (This Month)
        $thisMonth = Carbon::now()->startOfMonth();
        $monthlyLines = StockTransferLine::whereHas('transfer', function($q) use ($thisMonth, $baseQuery) {
            $q->where('doc_date', '>=', $thisMonth);
            // Apply the same warehouse scope to the relationship query
            $q->mergeConstraintsFrom($baseQuery);
        })->get();

        $monthlyShipped = $monthlyLines->sum('sent_quantity');
        $monthlyReceived = $monthlyLines->sum('actual_received_quantity');
        $completionRate = $monthlyShipped > 0 ? round(($monthlyReceived / $monthlyShipped) * 100) : 0;

        return [
            Stat::make(__('Pending Actions'), $pendingActions)
                ->description(__('Awaiting Shipment or Receipt'))
                ->descriptionIcon('heroicon-m-clock')
                ->color($pendingActions > 0 ? 'warning' : 'success')
                ->url(route('filament.admin.resources.stock-transfers.index', ['tableFilters[internal_status][value]' => StockTransfer::STATUS_SHIPPED])),

            Stat::make(__('Overdue Shipments (>1 Week)'), $overdueCount)
                ->description(__('Open requests older than 7 days'))
                ->descriptionIcon('heroicon-m-exclamation-triangle')
                ->color($overdueCount > 0 ? 'danger' : 'success')
                ->url(route('filament.admin.resources.stock-transfers.index', ['tableFilters[is_overdue][value]' => '1'])),

            Stat::make(__('Monthly Units Flow (Shipped vs Received)'), "{$monthlyReceived} / {$monthlyShipped}")
                ->description(__(':rate% of shipped units were safely received this month', ['rate' => $completionRate]))
                ->descriptionIcon('heroicon-m-chart-bar')
                ->color($completionRate < 100 ? 'warning' : 'success'),
        ];
    }
}
