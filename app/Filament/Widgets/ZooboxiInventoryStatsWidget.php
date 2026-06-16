<?php

namespace App\Filament\Widgets;

use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\DB;

class ZooboxiInventoryStatsWidget extends BaseWidget
{
    protected static bool $isDiscovered = false;

    protected function getStats(): array
    {
        $pi = DB::table('product_intelligence')->where('warehouse_code', '');

        $capital = (float) (clone $pi)->sum('capital_at_risk_sar');
        $overstock = (clone $pi)->where('health_status', 'overstock')->count();
        $dead = (clone $pi)->where('health_status', 'dead')->count();
        $reorder = (clone $pi)->whereIn('health_status', ['starved', 'stockout'])->count();
        $lostMo = (float) (clone $pi)->whereIn('health_status', ['starved', 'stockout'])->sum('lost_sales_monthly');
        $heroes = (clone $pi)->where('is_hero', 1)->count();

        return [
            Stat::make('رأس المال المتكدّس + الراكد', number_format($capital) . ' ر.س')
                ->description('فرصة التصريف — ' . number_format($overstock) . ' متكدّس · ' . number_format($dead) . ' راكد')
                ->color('danger'),

            Stat::make('منتجات تحتاج إعادة طلب', number_format($reorder))
                ->description('مقطوعة/نافدة — تخسر ~' . number_format($lostMo) . ' وحدة/شهر')
                ->color('warning'),

            Stat::make('المنتجات الأبطال (Heroes)', number_format($heroes))
                ->description('الأسرع دوراناً (≥100/شهر)')
                ->color('success'),
        ];
    }
}
