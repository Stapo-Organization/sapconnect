<?php

namespace App\Filament\Resources\SmsCampaignResource\Pages;

use App\Filament\Resources\SmsCampaignResource;
use App\Services\Sms\CampaignService;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;

class CreateSmsCampaign extends CreateRecord
{
    protected static string $resource = SmsCampaignResource::class;

    protected function afterCreate(): void
    {
        /** @var \App\Models\SmsCampaign $record */
        $record = $this->getRecord();

        // Parse the file
        try {
            $service = app(CampaignService::class);
            $service->parseFile($record);

            \Filament\Notifications\Notification::make()
                ->title('File Parsed')
                ->body("Parsed {$record->total_recipients} recipients.")
                ->success()
                ->send();

        } catch (\Exception $e) {
            \Filament\Notifications\Notification::make()
                ->title('Error Parsing File')
                ->body($e->getMessage())
                ->danger()
                ->send();
        }
    }
}
