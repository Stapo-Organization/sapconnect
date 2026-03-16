<?php

namespace App\Filament\Resources\BrandResource\Pages;

use App\Filament\Resources\BrandResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListBrands extends ListRecords
{
    protected static string $resource = BrandResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
            Actions\Action::make('importFromSap')
                ->label('Import from SAP')
                ->icon('heroicon-o-arrow-down-tray')
                ->color('success')
                ->action(function () {
                    \Illuminate\Support\Facades\Artisan::call('sap:sync-brands');
                    $output = \Illuminate\Support\Facades\Artisan::output();

                    // Simple regex to find count if possible, or just log the output
                    $count = 0;
                    if (preg_match('/Processed (\d+) records/', $output, $matches)) {
                        $count = (int) $matches[1];
                    }

                    \Filament\Notifications\Notification::make()
                        ->title("Brands Synced Successfully ($count processed)")
                        ->success()
                        ->send();

                    // Log to ApiLog
                    \App\Models\ApiLog::create([
                        'user_id' => auth()->id(),
                        'method' => 'IMPORT',
                        'endpoint' => 'ItemGroups', // Brands
                        'database_name' => session('sap_company_db', config('sap.company_db')),
                        'status_code' => 200,
                        'response_body' => json_encode([
                            'message' => 'Brands Import Triggered via UI',
                            'output' => trim($output),
                            'count' => $count
                        ]),
                        'ip_address' => request()->ip(),
                        'user_agent' => request()->userAgent(),
                    ]);
                }),
        ];
    }
}
