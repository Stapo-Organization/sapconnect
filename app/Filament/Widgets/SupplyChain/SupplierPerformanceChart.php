<?php

namespace App\Filament\Widgets\SupplyChain;

use App\Models\Supplier;
use Filament\Widgets\ChartWidget;

class SupplierPerformanceChart extends ChartWidget
{
    protected static ?string $heading = 'Top 10 Suppliers: Target vs Achieved';

    protected static ?string $pollingInterval = '120s';

    protected function getData(): array
    {
        $suppliers = Supplier::whereNotNull('target_amount')
            ->where('target_amount', '>', 0)
            ->orderByDesc('target_amount')
            ->limit(10)
            ->get();

        return [
            'datasets' => [
                [
                    'label' => 'Target Amount',
                    'data' => $suppliers->pluck('target_amount')->map(fn ($v) => (float)$v)->toArray(),
                    'backgroundColor' => 'rgba(59, 130, 246, 0.7)',
                    'borderColor' => '#3B82F6',
                ],
                [
                    'label' => 'Achieved Amount',
                    'data' => $suppliers->pluck('achieved_amount')->map(fn ($v) => (float)$v)->toArray(),
                    'backgroundColor' => 'rgba(16, 185, 129, 0.7)',
                    'borderColor' => '#10B981',
                ],
            ],
            'labels' => $suppliers->pluck('name')->toArray(),
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }
}
