<?php

namespace App\Livewire;

use App\Models\ZidOrder;
use App\Models\ZidStore;
use App\Services\Zid\ZidApiService;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\BadgeColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Actions\Action;
use Livewire\Component;
use Filament\Notifications\Notification;

class ZidOrdersList extends Component implements HasTable, HasForms
{
    use InteractsWithTable;
    use InteractsWithForms;

    public function table(Table $table): Table
    {
        return $table
            ->query(ZidOrder::query())
            ->columns([
                TextColumn::make('zid_order_id')->label('Order ID')->searchable()->sortable(),
                TextColumn::make('store.name')->label('Store')->sortable(),
                TextColumn::make('customer_name')->label('Customer')->searchable(),
                BadgeColumn::make('order_status')
                    ->label('Status')
                    ->colors([
                        'success' => fn($state) => in_array($state, ['Complete', 'Delivered', 'Ready']),
                        'warning' => fn($state) => in_array($state, ['New', 'Pending']),
                        'danger' => fn($state) => in_array($state, ['Canceled', 'Returned']),
                    ]),
                TextColumn::make('order_total')->label('Total')->money('SAR')->sortable(),
                TextColumn::make('order_date')->label('Date')->date()->sortable(),
            ])
            ->filters([
                SelectFilter::make('store_id')
                    ->label('Store')
                    ->options(ZidStore::all()->pluck('name', 'id')),
                SelectFilter::make('order_status')
                    ->label('Status')
                    ->options([
                        'new' => 'New',
                        'pending' => 'Pending',
                        'ready' => 'Ready',
                        'delivering' => 'Delivering',
                        'delivered' => 'Delivered',
                        'canceled' => 'Canceled',
                    ])
            ])
            ->headerActions([
                Action::make('sync_orders')
                    ->label('Sync Zid Orders')
                    ->icon('heroicon-o-arrow-path')
                    ->action(function () {
                        $this->syncOrders();
                    })
            ])
            ->actions([
                Action::make('view_details')
                    ->label('Details')
                    ->modalContent(fn(ZidOrder $record) => view('filament.pages.zid-order-details-modal', ['order' => $record->payload]))
                    ->modalSubmitAction(false)
            ])
            ->defaultSort('order_date', 'desc');
    }

    public function syncOrders()
    {
        $stores = ZidStore::all();
        $service = new ZidApiService();
        $newCount = 0;
        $updatedCount = 0;

        foreach ($stores as $store) {
            try {
                // Fetch latest 50 orders
                $data = $service->getOrders($store, ['per_page' => 50]);
                $orders = $data['orders'] ?? [];

                foreach ($orders as $orderData) {
                    $orderId = $orderData['id'];
                    $remoteUpdatedAt = \Carbon\Carbon::parse($orderData['updated_at'] ?? now());

                    $attributes = [
                        'store_id' => $store->id,
                        'customer_name' => $orderData['customer']['name'] ?? 'Guest',
                        'order_status' => $orderData['order_status']['name'] ?? 'Unknown',
                        'order_total' => $orderData['order_total'] ?? 0,
                        'order_date' => $orderData['created_at'] ?? now(),
                        'zid_updated_at' => $remoteUpdatedAt,
                        'payload' => $orderData,
                    ];

                    $order = ZidOrder::where('zid_order_id', $orderId)->first();

                    if (!$order) {
                        // NEW: Create
                        ZidOrder::create(array_merge(['zid_order_id' => $orderId], $attributes));
                        $newCount++;
                    } else {
                        // UPDATED: Check if remote updated_at > local zid_updated_at
                        $localUpdatedAt = $order->zid_updated_at;

                        // If local has no zid_updated_at (first run after migration), assume update needed
                        // OR if remote is newer
                        if (!$localUpdatedAt || $remoteUpdatedAt->gt($localUpdatedAt)) {
                            $order->fill($attributes);
                            $order->save();
                            $updatedCount++;
                        }
                    }
                }
            } catch (\Exception $e) {
                Notification::make()
                    ->title("Error syncing store {$store->name}")
                    ->body($e->getMessage())
                    ->danger()
                    ->send();
            }
        }

        $message = "Synced Zid Orders: {$newCount} New, {$updatedCount} Updated.";

        // Send SMS if there are updates or new orders
        if ($newCount > 0 || $updatedCount > 0) {
            $recipients = \App\Models\User::where('receive_sms_on_zid_import', true)
                ->whereNotNull('mobile_number')
                ->pluck('mobile_number')
                ->toArray();

            if (!empty($recipients)) {
                $smsService = new \App\Services\SMS\TaqnyatService();
                $smsService->sendSms($recipients, $message);
            }
        }

        Notification::make()
            ->title('Sync Complete')
            ->body($message)
            ->success()
            ->send();
    }

    public function render()
    {
        return view('livewire.zid-orders-list');
    }
}
