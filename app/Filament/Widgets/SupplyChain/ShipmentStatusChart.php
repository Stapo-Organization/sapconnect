<?php

namespace App\Filament\Widgets\SupplyChain;

use App\Models\Shipment;
use Filament\Widgets\ChartWidget;

class ShipmentStatusChart extends ChartWidget
{
    protected static ?string $heading = 'Shipment Status Distribution';

    protected static ?string $pollingInterval = '60s';

    protected function getData(): array
    {
        $statuses = [
            'scheduled' => Shipment::where('status', 'scheduled')->count(),
            'shipped' => Shipment::where('status', 'shipped')->count(),
            'arrived_port' => Shipment::where('status', 'arrived_port')->count(),
            'delivered' => Shipment::where('status', 'delivered')->count(),
        ];

        return [
            'datasets' => [
                [
                    'label' => 'Shipments',
                    'data' => array_values($statuses),
                    'backgroundColor' => [
                        '#F59E0B', // warning - scheduled
                        '#3B82F6', // primary - shipped
                        '#06B6D4', // info - arrived_port
                        '#10B981', // success - delivered
                    ],
                ],
            ],
            'labels' => ['Scheduled', 'Shipped', 'Arrived at Port', 'Delivered'],
        ];
    }

    protected function getType(): string
    {
        return 'doughnut';
    }
}
