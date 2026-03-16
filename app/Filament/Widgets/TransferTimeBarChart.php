<?php

namespace App\Filament\Widgets;

use App\Models\StockTransfer;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class TransferTimeBarChart extends ChartWidget
{
    protected static ?string $heading = 'Average Delivery Time By Branch (Days)';
    protected static ?string $description = 'Time from Shipment to Actual Receipt';

    // Sort next to the Donut Chart
    protected static ?int $sort = 4;

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected function getData(): array
    {
        // Calculates average delivery time (in days) per warehouse
        // We only look at Completed transfers from the last 90 days.
        $ninetyDaysAgo = Carbon::now()->subDays(90);

        $deliveryTimes = StockTransfer::where('internal_status', StockTransfer::STATUS_COMPLETED)
            ->whereNotNull('sent_at')
            ->whereNotNull('received_at')
            ->where('received_at', '>=', $ninetyDaysAgo)
            ->select('to_warehouse', DB::raw('AVG(TIMESTAMPDIFF(DAY, sent_at, received_at)) as avg_days'))
            ->groupBy('to_warehouse')
            ->orderByDesc('avg_days')
            ->limit(10) // Top 10 slowest or most active branches
            ->get();

        $labels = [];
        $data = [];

        foreach ($deliveryTimes as $stat) {
            $labels[] = $stat->toWarehouse ? $stat->toWarehouse->warehouse_name : $stat->to_warehouse;
            $data[] = round($stat->avg_days, 1);
        }

        return [
            'datasets' => [
                [
                    'label' => __('Avg Days'),
                    'data' => $data,
                    'backgroundColor' => '#f87171', // Redish to show delay
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}
