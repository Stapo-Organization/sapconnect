<?php

namespace App\Filament\Resources\ProductResource\Pages;

use App\Filament\Resources\ProductResource;
use App\Models\Product;
use App\Services\SAP\SapClient;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Filament\Resources\Components\Tab;
use Illuminate\Database\Eloquent\Builder;
use Filament\Notifications\Notification;

class ListProducts extends ListRecords
{
    protected static string $resource = ProductResource::class;

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

                        // 2. Fetch Data (Filtered by ItemCode startswith 'P')
                        // We need to fetch all pages.
                        $queryParams = [
                            '$filter' => "startswith(ItemCode, 'P')",
                            '$select' => 'ItemCode,ItemName,ForeignName,ItemsGroupCode,InventoryUOM,SalesItemsPerUnit,ItemBarCodeCollection,CreateDate,UpdateDate',
                            '$top' => 100, // Fetch 100 at a time
                            '$skip' => 0
                        ];

                        $count = 0;
                        $fetched = 0;

                        do {
                            $response = $sap->get('Items', $queryParams);

                            if (empty($response['value'])) {
                                break;
                            }

                            $items = $response['value'];
                            $batchCount = count($items);
                            $fetched = $batchCount; // Update fetched count to check if we should continue
        
                            foreach ($items as $item) {
                                // Manual extraction logic (replicating 'PieceBarcode' view logic)
                                $pieceBarcode = null;
                                if (!empty($item['ItemBarCodeCollection'])) {
                                    foreach ($item['ItemBarCodeCollection'] as $bc) {
                                        if (isset($bc['FreeText']) && $bc['FreeText'] === 'Piece') {
                                            $pieceBarcode = $bc['Barcode'];
                                            break;
                                        }
                                    }
                                }

                                Product::updateOrCreate(
                                    [
                                        'item_code' => $item['ItemCode'],
                                        'source' => $env
                                    ],
                                    [
                                        'item_name' => $item['ItemName'] ?? null,
                                        'foreign_name' => $item['ForeignName'] ?? null,
                                        'items_group_code' => $item['ItemsGroupCode'] ?? null,
                                        'inventory_uom' => $item['InventoryUOM'] ?? null,
                                        'piece_barcode' => $pieceBarcode,
                                        'sales_items_per_unit' => $item['SalesItemsPerUnit'] ?? null,
                                        'create_date' => isset($item['CreateDate']) ? \Carbon\Carbon::parse($item['CreateDate'])->toDateTimeString() : null,
                                        'update_date' => isset($item['UpdateDate']) ? \Carbon\Carbon::parse($item['UpdateDate'])->toDateTimeString() : null,
                                    ]
                                );
                                $count++;
                            }

                            // Increment skip for next page
                            $queryParams['$skip'] += $batchCount;

                            // We rely on the while($batchCount > 0) to stop.
                            // The server might return fewer items than $top if it has a max page size (e.g. 20),
                            // so checking ($batchCount < $top) causes premature exit.
        

                        } while ($batchCount > 0);

                        if ($count === 0) {
                            Notification::make()
                                ->title('No products found matching criteria.')
                                ->warning()
                                ->send();

                            // Log Attempt (No data)
                            \App\Models\ApiLog::create([
                                'user_id' => auth()->id(),
                                'method' => 'IMPORT',
                                'endpoint' => 'Items',
                                'database_name' => $env, // Or $sapDb
                                'status_code' => 200,
                                'response_body' => json_encode(['message' => 'No products found matching criteria.']),
                                'ip_address' => request()->ip(),
                                'user_agent' => request()->userAgent(),
                            ]);
                            return;
                        }

                        Notification::make()
                            ->title("Successfully imported {$count} products for {$env}. (Logged)")
                            ->success()
                            ->send();

                        \Illuminate\Support\Facades\Log::info("Imported $count products for $env. Attempting to create ApiLog.");

                        // Log Success
                        \App\Models\ApiLog::create([
                            'user_id' => auth()->id(),
                            'method' => 'IMPORT',
                            'endpoint' => 'Items',
                            'database_name' => $env,
                            'status_code' => 200,
                            'response_body' => json_encode(['message' => "Successfully imported {$count} products.", 'count' => $count]),
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
                            'endpoint' => 'Items',
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
