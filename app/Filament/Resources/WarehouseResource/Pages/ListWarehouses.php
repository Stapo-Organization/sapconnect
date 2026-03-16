<?php

namespace App\Filament\Resources\WarehouseResource\Pages;

use App\Filament\Resources\WarehouseResource;
use App\Models\Warehouse;
use App\Services\SAP\SapClient;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Filament\Notifications\Notification;

class ListWarehouses extends ListRecords
{
    protected static string $resource = WarehouseResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
            Actions\Action::make('import_from_sap')
                ->label('Import from SAP')
                ->icon('heroicon-o-arrow-down-tray')
                ->color('primary')
                ->action(function () {
                    $env = 'production';

                    try {
                        // 1. Initialize SAP Client
                        $sap = app(SapClient::class);
                        $sap->setCompanyDb('PPTC_V5_PROD');

                        // 2. Fetch Data
                        // Need to fetch all pages.
                        $queryParams = [
                            '$select' => 'WarehouseCode,WarehouseName',
                            '$top' => 100, // Fetch 100 at a time
                            '$skip' => 0
                        ];

                        $count = 0;
                        $fetched = 0;

                        do {
                            $response = $sap->get('Warehouses', $queryParams);

                            if (empty($response['value'])) {
                                break;
                            }

                            $items = $response['value'];
                            $batchCount = count($items);

                            foreach ($items as $item) {
                                Warehouse::updateOrCreate(
                                    [
                                        'warehouse_code' => $item['WarehouseCode'],
                                        'source' => $env
                                    ],
                                    [
                                        'warehouse_name' => $item['WarehouseName'] ?? null,
                                    ]
                                );
                                $count++;
                            }

                            // Increment skip for next page
                            $queryParams['$skip'] += $batchCount;

                            // We rely on the while($batchCount > 0) to stop.
                            // The server might return fewer items than $top if it has a max page size,
                            // so checking ($batchCount < $top) creates a risk of premature exit.
        
                        } while ($batchCount > 0);

                        if ($count === 0) {
                            Notification::make()
                                ->title('No warehouses found.')
                                ->warning()
                                ->send();

                            // Log Attempt (No data)
                            \App\Models\ApiLog::create([
                                'user_id' => auth()->id(),
                                'method' => 'IMPORT',
                                'endpoint' => 'Warehouses',
                                'database_name' => $env,
                                'status_code' => 200,
                                'response_body' => json_encode(['message' => 'No warehouses found.']),
                                'ip_address' => request()->ip(),
                                'user_agent' => request()->userAgent(),
                            ]);
                            return;
                        }

                        Notification::make()
                            ->title("Successfully imported {$count} warehouses for {$env}.")
                            ->success()
                            ->send();

                        // Log Success
                        \App\Models\ApiLog::create([
                            'user_id' => auth()->id(),
                            'method' => 'IMPORT',
                            'endpoint' => 'Warehouses',
                            'database_name' => $env,
                            'status_code' => 200,
                            'response_body' => json_encode(['message' => "Successfully imported {$count} warehouses.", 'count' => $count]),
                            'ip_address' => request()->ip(),
                            'user_agent' => request()->userAgent(),
                        ]);

                    } catch (\Exception $e) {
                        Notification::make()
                            ->title('Import Failed')
                            ->body($e->getMessage())
                            ->danger()
                            ->send();

                        // Log Failure
                        \App\Models\ApiLog::create([
                            'user_id' => auth()->id(),
                            'method' => 'IMPORT',
                            'endpoint' => 'Warehouses',
                            'database_name' => $env,
                            'status_code' => 500,
                            'response_body' => json_encode(['error' => $e->getMessage()]),
                            'ip_address' => request()->ip(),
                            'user_agent' => request()->userAgent(),
                        ]);
                    }
                }),
        ];
    }
}
