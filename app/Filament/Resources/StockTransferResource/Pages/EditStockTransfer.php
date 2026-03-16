<?php

namespace App\Filament\Resources\StockTransferResource\Pages;

use App\Filament\Resources\StockTransferResource;
use App\Models\StockTransfer;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Filament\Notifications\Notification;

class EditStockTransfer extends EditRecord
{
    protected static string $resource = StockTransferResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('mark_as_shipped')
                ->label('Confirm & Ship')
                ->color('warning')
                ->icon('heroicon-m-truck')
                ->visible(function (StockTransfer $record) {
                    if ($record->internal_status !== StockTransfer::STATUS_NEW) return false;
                    $user = auth()->user();
                    $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                    $codes = array_filter($codes);
                    return empty($codes) || in_array($record->from_warehouse, $codes);
                })
                ->action(function (StockTransfer $record, $livewire) {
                    // Save any unsaved quantities in the form first
                    $livewire->save();
                    
                    $record->refresh();
                    
                    if ($record->lines()->sum('sent_quantity') <= 0) {
                        Notification::make()->title('Cannot Ship')->body('Please enter sent quantities greater than 0 first.')->danger()->send();
                        return;
                    }

                    $record->update([
                        'internal_status' => StockTransfer::STATUS_SHIPPED,
                        'sent_by' => auth()->id(),
                        'sent_at' => now(),
                    ]);

                    \App\Models\StockTransferLog::record(
                        $record->id, auth()->id(), \App\Models\StockTransferLog::ACTION_SEND_CONFIRMED,
                        StockTransfer::STATUS_NEW, StockTransfer::STATUS_SHIPPED,
                        ['total_sent_qty' => $record->lines()->sum('sent_quantity')],
                        request()->ip()
                    );

                    try {
                        app(\App\Services\NotificationService::class)->notifyWarehouseUsers(
                            $record->to_warehouse,
                            'شحنة جديدة في الطريق',
                            "تحويل المخزون #{$record->doc_num} تم شحنه من {$record->from_warehouse}. يرجى مراجعة واستلام البضاعة.",
                            ['transfer_id' => $record->id, 'doc_num' => $record->doc_num]
                        );
                    } catch (\Exception $e) {
                        \Illuminate\Support\Facades\Log::error("Failed to notify receiver: " . $e->getMessage());
                    }

                    Notification::make()->title('Transfer Shipped!')->success()->send();
                    $livewire->redirect($this->getResource()::getUrl('index'));
                })
                ->requiresConfirmation()
                ->modalDescription('Save quantities and mark this transfer as Shipped?'),

            Actions\Action::make('mark_as_received')
                ->label('Confirm & Receive')
                ->color('success')
                ->icon('heroicon-m-check-badge')
                ->visible(function (StockTransfer $record) {
                    if ($record->internal_status !== StockTransfer::STATUS_SHIPPED) return false;
                    $user = auth()->user();
                    $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                    $codes = array_filter($codes);
                    return empty($codes) || in_array($record->to_warehouse, $codes);
                })
                ->action(function (StockTransfer $record, $livewire) {
                    $livewire->save();
                    $record->refresh();

                    $record->update([
                        'internal_status' => StockTransfer::STATUS_COMPLETED,
                        'received_by' => auth()->id(),
                        'received_at' => now(),
                    ]);

                    \App\Models\StockTransferLog::record(
                        $record->id, auth()->id(), \App\Models\StockTransferLog::ACTION_RECEIVE_CONFIRMED,
                        StockTransfer::STATUS_SHIPPED, StockTransfer::STATUS_COMPLETED,
                        ['total_received_qty' => $record->lines()->sum('actual_received_quantity')],
                        request()->ip()
                    );

                    try {
                        app(\App\Services\NotificationService::class)->notifyWarehouseUsers(
                            $record->from_warehouse,
                            'تم استلام الشحنة',
                            "تحويل المخزون #{$record->doc_num} تم استلامه في {$record->to_warehouse}.",
                            ['transfer_id' => $record->id, 'doc_num' => $record->doc_num]
                        );
                    } catch (\Exception $e) {
                        \Illuminate\Support\Facades\Log::error("Failed to notify sender: " . $e->getMessage());
                    }

                    Notification::make()->title('Transfer Received!')->success()->send();
                    $livewire->redirect($this->getResource()::getUrl('index'));
                })
                ->requiresConfirmation()
                ->modalDescription('Save quantities and mark this transfer as Received?'),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
