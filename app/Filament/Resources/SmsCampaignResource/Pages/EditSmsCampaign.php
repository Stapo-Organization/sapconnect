<?php

namespace App\Filament\Resources\SmsCampaignResource\Pages;

use App\Filament\Resources\SmsCampaignResource;
use App\Services\Sms\CampaignService;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;

class EditSmsCampaign extends EditRecord
{
    protected static string $resource = SmsCampaignResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),

            Actions\Action::make('test_send')
                ->label('Test Send')
                ->icon('heroicon-o-paper-airplane')
                ->color('info')
                ->form(function (SmsCampaignResource\Pages\EditSmsCampaign $livewire) {
                    $record = $livewire->getRecord();
                    $message = $record->message_body;

                    // Extract variables like {LTY_BALANCE}
                    preg_match_all('/\{([a-zA-Z0-9_]+)\}/', $message, $matches);
                    $vars = array_unique($matches[1] ?? []);

                    $schema = [
                        TextInput::make('test_number')
                            ->label('Test Number')
                            ->default('966500141072')
                            ->required(),
                    ];

                    if (!empty($vars)) {
                        $schema[] = \Filament\Forms\Components\Section::make('Variables')
                            ->schema(
                                array_map(function ($var) {
                                    return TextInput::make('variables.' . $var)
                                        ->label($var);
                                }, $vars)
                            );
                    }

                    return $schema;
                })
                ->action(function (array $data, CampaignService $service) {
                    try {
                        $success = $service->sendTest($this->getRecord(), $data['test_number'], $data['variables'] ?? []);
                        if ($success) {
                            Notification::make()->title('Test SMS Sent')->success()->send();
                        } else {
                            Notification::make()->title('Test SMS Failed')->danger()->send();
                        }
                    } catch (\Exception $e) {
                        Notification::make()->title('Error')->body($e->getMessage())->danger()->send();
                    }
                }),

            Actions\Action::make('send_all')
                ->label('Send to All')
                ->icon('heroicon-o-rocket-launch')
                ->color('success')
                ->requiresConfirmation()
                ->modalHeading('Send Campaign to All Recipients')
                ->modalDescription(function ($record) {
                    $pendingCount = $record->recipients()->where('status', 'pending')->count();
                    return "Are you sure you want to send this campaign to {$pendingCount} pending recipients (out of {$record->total_recipients} total)? This cannot be undone.";
                })
                ->action(function (CampaignService $service) {
                    try {
                        $service->sendCampaign($this->getRecord());
                        Notification::make()->title('Campaign Processing Started')->success()->send();
                    } catch (\Exception $e) {
                        Notification::make()->title('Error')->body($e->getMessage())->danger()->send();
                    }
                })
                ->visible(fn($record) => $record->status !== 'completed'),

            Actions\Action::make('reprocess_file')
                ->label('Reprocess File')
                ->color('gray')
                ->requiresConfirmation()
                ->action(function (CampaignService $service) {
                    try {
                        // Clear existing recipients? Maybe not to avoid data loss if file is same.
                        // For now just parse and add/update. 
                        // Implementation detail: parseFile doesn't clear.
                        // But for robustness, let's clear if we reprocess.
                        $this->getRecord()->recipients()->delete();

                        $service->parseFile($this->getRecord());

                        Notification::make()
                            ->title('File Reprocessed')
                            ->body("Parsed {$this->getRecord()->total_recipients} recipients.")
                            ->success()
                            ->send();

                        $this->refreshFormData(['total_recipients']);

                    } catch (\Exception $e) {
                        Notification::make()->title('Error')->body($e->getMessage())->danger()->send();
                    }
                }),
        ];
    }
}
