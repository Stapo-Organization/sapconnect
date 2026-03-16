<?php

namespace App\Filament\Widgets;

use App\Models\StockTransfer;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Carbon\Carbon;

class BranchManagerStats extends BaseWidget
{
    protected static ?int $sort = 1;

    public static function canView(): bool
    {
        return auth()->user()->hasRole('Branch Manager');
    }

    protected function getStats(): array
    {
        $user = auth()->user();
        $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
        $codes = array_filter($codes);

        if (empty($codes)) {
            return [];
        }

        $primaryCode = reset($codes);

        // Pending Incoming: New or Shipped and heading to this branch (not yet completed)
        $pendingIncoming = StockTransfer::whereIn('to_warehouse', $codes)
            ->whereIn('internal_status', [StockTransfer::STATUS_NEW, StockTransfer::STATUS_SHIPPED])
            ->count();

        // Pending Outgoing: New and leaving this branch
        $pendingOutgoing = StockTransfer::whereIn('from_warehouse', $codes)
            ->where('internal_status', StockTransfer::STATUS_NEW)
            ->count();

        // Delayed Transfers: Open (not Completed) and older than 30 days
        $delayedTransfers = StockTransfer::where(function ($query) use ($codes) {
                $query->whereIn('from_warehouse', $codes)
                      ->orWhereIn('to_warehouse', $codes);
            })
            ->whereIn('internal_status', [StockTransfer::STATUS_NEW, StockTransfer::STATUS_SHIPPED])
            ->where('doc_date', '<', Carbon::now()->subDays(7))
            ->count();

        // Completed This Month
        $completedThisMonth = StockTransfer::where(function ($query) use ($codes) {
                $query->whereIn('from_warehouse', $codes)
                      ->orWhereIn('to_warehouse', $codes);
            })
            ->where('internal_status', StockTransfer::STATUS_COMPLETED)
            ->where('updated_at', '>=', Carbon::now()->startOfMonth())
            ->count();

        return [
            Stat::make(__('شحنات واردة قيد الانتظار'), $pendingIncoming)
                ->description(__('في الطريق أو قيد التجهيز للمستودع'))
                ->descriptionIcon('heroicon-m-arrow-down-tray')
                ->color('warning')
                ->url(route('filament.admin.resources.stock-transfers.index', [
                    'tableFilters[internal_status][values][0]' => StockTransfer::STATUS_NEW,
                    'tableFilters[internal_status][values][1]' => StockTransfer::STATUS_SHIPPED,
                    'tableFilters[to_warehouse][value]' => $primaryCode,
                ])),

            Stat::make(__('شحنات صادرة قيد الانتظار'), $pendingOutgoing)
                ->description(__('تنتظر الشحن'))
                ->descriptionIcon('heroicon-m-arrow-up-tray')
                ->color('gray')
                ->url(route('filament.admin.resources.stock-transfers.index', [
                    'tableFilters[internal_status][value]' => StockTransfer::STATUS_NEW,
                    'tableFilters[from_warehouse][value]' => $primaryCode,
                ])),

            Stat::make(__('شحنات متأخرة جداً'), $delayedTransfers)
                ->description(__('تجاوزت اسبوع - يرجى المتابعة'))
                ->descriptionIcon('heroicon-m-exclamation-triangle')
                ->color($delayedTransfers > 0 ? 'danger' : 'success')
                ->url(route('filament.admin.resources.stock-transfers.index', [
                    'tableFilters[is_overdue][value]' => '1',
                ])),

            Stat::make(__('شحنات مكتملة (هذا الشهر)'), $completedThisMonth)
                ->description(__('شحنات تم إغلاقها بنجاح'))
                ->descriptionIcon('heroicon-m-check-badge')
                ->color('success')
                ->url(route('filament.admin.resources.stock-transfers.index', [
                    'tableFilters[internal_status][value]' => StockTransfer::STATUS_COMPLETED,
                ])),
        ];
    }
}
