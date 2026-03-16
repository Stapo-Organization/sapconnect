<?php

namespace App\Filament\Resources\StockTransferResource\Pages;

use App\Filament\Resources\StockTransferResource;
use App\Models\StockTransfer;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Filament\Notifications\Notification;
use Filament\Forms;
use Illuminate\Support\Facades\Blade;

class EditStockTransfer extends EditRecord
{
    protected static string $resource = StockTransferResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('scan_barcode')
                ->label(__('مسح باركود المنتج'))
                ->icon('heroicon-m-qr-code')
                ->color('info')
                ->form([
                    Forms\Components\TextInput::make('barcode')
                        ->label(__('رقم الباركود'))
                        ->required()
                        ->autofocus()
                        ->extraInputAttributes(['autocomplete' => 'off']),
                ])
                ->modalWidth('md')
                ->modalSubmitActionLabel(__('بحث ومطابقة'))
                ->action(function (array $data, StockTransfer $record, Actions\Action $action) {
                    $barcode = trim($data['barcode']);
                    
                    // 1. Find Product by barcode
                    $product = \App\Models\Product::where('piece_barcode', $barcode)->first();
                    
                    if (!$product) {
                        Notification::make()->title(__('Product Not Found'))->body(__('المنتج غير موجود أو لا يملك هذا الباركود'))->danger()->send();
                        $action->halt();
                    }
                    
                    // 2. Find if product is inside the transfer lines
                    $line = $record->lines()->where('item_code', $product->item_code)->first();
                    
                    if (!$line) {
                        Notification::make()->title(__('Item Not In Transfer'))->body(__('هذا المنتج غير موجود في طلب التحويل الحالي'))->danger()->send();
                        $action->halt();
                    }
                    
                    // 3. Determine user role and which quantity to update based on internal_status
                    $canUpdateSent = false;
                    $canUpdateReceived = false;
                    $user = auth()->user();
                    $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                    $codes = array_filter($codes);
                    
                    if ($record->internal_status === StockTransfer::STATUS_NEW) {
                        if (empty($codes) || in_array($record->from_warehouse, $codes)) {
                            $canUpdateSent = true;
                        }
                    } elseif ($record->internal_status === StockTransfer::STATUS_SHIPPED) {
                        if (empty($codes) || in_array($record->to_warehouse, $codes)) {
                            $canUpdateReceived = true;
                        }
                    }
                    
                    if (!$canUpdateSent && !$canUpdateReceived) {
                        Notification::make()->title(__('Unauthorized'))->body(__('ليس لديك صلاحية لتحديث كميات هذا الطلب في حالته الحالية'))->danger()->send();
                        $action->halt();
                    }

                    // Open Step 2: Confirm Quantity
                    $this->replaceMountedAction('confirm_quantity', [
                        'line_id' => $line->id,
                        'item_code' => $product->item_code,
                        'item_name' => $product->item_name,
                        'expected_qty' => $line->quantity,
                        'current_sent' => $line->sent_quantity,
                        'current_received' => $line->actual_received_quantity,
                        'update_type' => $canUpdateSent ? 'sent' : 'received',
                    ]);
                }),

            Actions\Action::make('confirm_quantity')
                ->hidden() // Sub action
                ->modalWidth('sm')
                ->modalHeading(__('تأكيد الكمية المقبولة/المرسلة'))
                ->modalSubmitActionLabel(__('حفظ ومسح التالي'))
                ->form(function(array $arguments) {
                    return [
                        Forms\Components\ViewField::make('preview')
                            ->view('filament.components.product-scan-preview')
                            ->viewData([
                                'itemCode' => $arguments['item_code'] ?? '',
                                'itemName' => $arguments['item_name'] ?? '',
                                'expectedQty' => $arguments['expected_qty'] ?? 0,
                            ]),
                        Forms\Components\TextInput::make('quantity')
                            ->label($arguments['update_type'] === 'sent' ? __('الكمية المرسلة') : __('الكمية المستلمة الفعليا'))
                            ->numeric()
                            ->required()
                            ->autofocus()
                            ->default(function() use ($arguments) {
                                // Default to whatever is currently saved in DB or 0
                                return $arguments['update_type'] === 'sent' 
                                    ? ($arguments['current_sent'] ?? 0) 
                                    : ($arguments['current_received'] ?? 0);
                            })
                            ->extraInputAttributes([
                                'x-init' => 'setTimeout(() => { $el.select() }, 100)' // Auto-select text
                            ]),
                    ];
                })
                ->action(function (array $data, array $arguments, $livewire) {
                    $lineId = $arguments['line_id'];
                    $qty = (float) $data['quantity'];
                    $type = $arguments['update_type'];
                    
                    $line = \App\Models\StockTransferLine::find($lineId);
                    if ($line) {
                        if ($type === 'sent') {
                            $line->update(['sent_quantity' => $qty]);
                        } else {
                            $line->update(['actual_received_quantity' => $qty]);
                        }

                        // Refresh Filament form records/state so UI is updated immediately
                        $livewire->fillForm();

                        Notification::make()->title(__('تم الحفظ!'))->success()->send();
                        
                        // Trick to automatically go back to scanning
                        $this->replaceMountedAction('scan_barcode');
                    }
                }),

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
