<?php

namespace App\Filament\Widgets;

use App\Models\StockTransfer;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Facades\DB;

class TransferStatusDonutChart extends ChartWidget
{
    protected static ?string $heading = 'Transfer Status Distribution';
    
    // Sort after the two stat rows
    protected static ?int $sort = 3;

    protected function getData(): array
    {
        // Get the counts for each status
        $statuses = StockTransfer::select('internal_status', DB::raw('count(*) as total'))
            ->groupBy('internal_status')
            ->pluck('total', 'internal_status')
            ->toArray();

        // Default values if no data exists
        $new = $statuses[StockTransfer::STATUS_NEW] ?? 0;
        $shipped = $statuses[StockTransfer::STATUS_SHIPPED] ?? 0;
        $received = $statuses[StockTransfer::STATUS_RECEIVED] ?? 0;
        $completed = $statuses[StockTransfer::STATUS_COMPLETED] ?? 0;

        return [
            'datasets' => [
                [
                    'label' => 'Total Transfers',
                    'data' => [$new, $shipped, $received, $completed],
                    'backgroundColor' => [
                        '#9ca3af', // Gray for New
                        '#fbbf24', // Yellow for Shipped
                        '#60a5fa', // Blue for Received
                        '#34d399', // Green for Completed
                    ],
                ],
            ],
            'labels' => [__('New'), __('Shipped'), __('Received'), __('Completed')],
        ];
    }

    protected function getType(): string
    {
        return 'doughnut';
    }
}
