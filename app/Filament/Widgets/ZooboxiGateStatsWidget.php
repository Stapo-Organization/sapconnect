<?php

namespace App\Filament\Widgets;

use App\Models\Product;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\DB;

class ZooboxiGateStatsWidget extends BaseWidget
{
    protected static ?string $pollingInterval = '60s';

    protected function getStats(): array
    {
        $since = now()->subDays(7);
        $activated7d = DB::table('zooboxi_gate_events')->where('action', 'activated')->where('created_at', '>=', $since)->count();
        $activatedToday = DB::table('zooboxi_gate_events')->where('action', 'activated')->where('created_at', '>=', now()->startOfDay())->count();
        $held = Product::production()->where('zooboxi_active', false)->where('zooboxi_gate_status', 'held')->count();
        $noImage = Product::production()->where('zooboxi_active', false)->where('zooboxi_gate_status', 'held')->where('zooboxi_gate_reasons', 'like', '%"no_image"%')->count();
        $ai = Product::where('zb_content_source', 'ai')->count();
        $lastRun = Product::max('zooboxi_gate_checked_at');

        return [
            Stat::make('نُشر تلقائيًا (7 أيام)', $activated7d)
                ->description("اليوم: {$activatedToday}")->color('success')->icon('heroicon-o-rocket-launch'),
            Stat::make('محجوز', $held)
                ->description("بدون صورة: {$noImage}")->color($held > 0 ? 'warning' : 'gray')->icon('heroicon-o-hand-raised'),
            Stat::make('محتوى كُتب آليًا', $ai)
                ->description('راجعه من صفحة المنتجات')->color('info')->icon('heroicon-o-sparkles'),
            Stat::make('آخر فحص', $lastRun ? \Carbon\Carbon::parse($lastRun)->diffForHumans() : '—')
                ->description('كل 15 دقيقة')->color('gray')->icon('heroicon-o-clock'),
        ];
    }
}
