<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZooboxiOrderResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\ZooboxiOrder;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Filament\Infolists;
use Filament\Infolists\Infolist;

class ZooboxiOrderResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = ZooboxiOrder::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-cart';

    protected static ?string $slug = 'zooboxi-orders';

    public static function getNavigationLabel(): string
    {
        return __('Zooboxi Orders');
    }

    public static function getModelLabel(): string
    {
        return __('Order');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Zooboxi Orders');
    }

    public static function getNavigationGroup(): ?string
    {
        return '🛒 Zooboxi Store';
    }

    protected static ?int $navigationSort = 3;

    public static function getNavigationBadge(): ?string
    {
        $pending = static::getModel()::where('delivery_status', 'pending')->count();
        return $pending > 0 ? (string) $pending : null;
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'warning';
    }

    public static function canCreate(): bool
    {
        return false; // Orders come from WooCommerce, not created manually
    }

    public static function form(Form $form): Form
    {
        return $form->schema([]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                Tables\Columns\TextColumn::make('woo_order_id')
                    ->label(__('WC Order #'))
                    ->searchable()
                    ->sortable()
                    ->weight('bold')
                    ->copyable()
                    ->prefix('#'),

                Tables\Columns\TextColumn::make('customer_name')
                    ->label(__('Customer'))
                    ->searchable()
                    ->limit(25),

                Tables\Columns\TextColumn::make('customer_phone')
                    ->label(__('Phone'))
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('customer_city')
                    ->label(__('City'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'Riyadh', 'الرياض' => 'success',
                        'Jeddah', 'جدة' => 'info',
                        default => 'gray',
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('delivery_type')
                    ->label(__('Delivery Type'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'express' => 'danger',
                        'same_day' => 'warning',
                        'shipping' => 'info',
                        'pickup' => 'success',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'express' => '🚀 Express',
                        'same_day' => '📦 Same Day',
                        'shipping' => '🚚 Shipping',
                        'pickup' => '🏬 Pickup',
                        default => $state,
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('delivery_status')
                    ->label(__('Status'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'pending' => 'warning',
                        'preparing' => 'info',
                        'ready_for_pickup' => 'primary',
                        'out_for_delivery' => 'info',
                        'delivered' => 'success',
                        'cancelled' => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'pending' => __('Pending'),
                        'preparing' => __('Preparing'),
                        'ready_for_pickup' => __('Ready'),
                        'out_for_delivery' => __('Out for Delivery'),
                        'delivered' => __('Delivered'),
                        'cancelled' => __('Cancelled'),
                        default => $state,
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->sortable()
                    ->badge()
                    ->color('gray'),

                Tables\Columns\TextColumn::make('total_amount')
                    ->label(__('Total'))
                    ->money('SAR')
                    ->sortable()
                    ->alignEnd(),

                Tables\Columns\TextColumn::make('payment_status')
                    ->label(__('Payment'))
                    ->badge()
                    ->color(fn (?string $state): string => match ($state) {
                        'paid' => 'success',
                        'pending' => 'warning',
                        'refunded' => 'danger',
                        default => 'gray',
                    })
                    ->toggleable(),

                Tables\Columns\IconColumn::make('sap_synced')
                    ->label(__('SAP'))
                    ->state(fn (ZooboxiOrder $record) => $record->sap_synced_at !== null)
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-clock')
                    ->trueColor('success')
                    ->falseColor('gray')
                    ->alignCenter()
                    ->toggleable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('Order Date'))
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('delivery_type')
                    ->label(__('Delivery Type'))
                    ->options([
                        'express' => '🚀 Express',
                        'same_day' => '📦 Same Day',
                        'shipping' => '🚚 Shipping',
                        'pickup' => '🏬 Pickup',
                    ]),

                Tables\Filters\SelectFilter::make('delivery_status')
                    ->label(__('Status'))
                    ->options([
                        'pending' => __('Pending'),
                        'preparing' => __('Preparing'),
                        'ready_for_pickup' => __('Ready for Pickup'),
                        'out_for_delivery' => __('Out for Delivery'),
                        'delivered' => __('Delivered'),
                        'cancelled' => __('Cancelled'),
                    ]),

                Tables\Filters\SelectFilter::make('customer_city')
                    ->label(__('City'))
                    ->options(fn () => ZooboxiOrder::whereNotNull('customer_city')
                        ->distinct()
                        ->pluck('customer_city', 'customer_city')
                        ->toArray()),

                Tables\Filters\SelectFilter::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->options(fn () => ZooboxiOrder::whereNotNull('warehouse_code')
                        ->distinct()
                        ->pluck('warehouse_code', 'warehouse_code')
                        ->toArray()),

                Tables\Filters\SelectFilter::make('payment_status')
                    ->label(__('Payment'))
                    ->options([
                        'paid' => __('Paid'),
                        'pending' => __('Pending'),
                        'refunded' => __('Refunded'),
                    ]),

                Tables\Filters\TernaryFilter::make('sap_synced')
                    ->label(__('SAP Synced'))
                    ->queries(
                        true: fn (Builder $query) => $query->whereNotNull('sap_synced_at'),
                        false: fn (Builder $query) => $query->whereNull('sap_synced_at'),
                    ),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Section::make(__('Order Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('woo_order_id')
                            ->label(__('WooCommerce Order #'))
                            ->prefix('#')
                            ->copyable(),
                        Infolists\Components\TextEntry::make('delivery_type')
                            ->label(__('Delivery Type'))
                            ->badge()
                            ->color(fn (string $state): string => match ($state) {
                                'express' => 'danger',
                                'same_day' => 'warning',
                                'shipping' => 'info',
                                'pickup' => 'success',
                                default => 'gray',
                            }),
                        Infolists\Components\TextEntry::make('delivery_status')
                            ->label(__('Delivery Status'))
                            ->badge()
                            ->color(fn (string $state): string => match ($state) {
                                'pending' => 'warning',
                                'preparing' => 'info',
                                'delivered' => 'success',
                                'cancelled' => 'danger',
                                default => 'gray',
                            }),
                        Infolists\Components\TextEntry::make('warehouse_code')
                            ->label(__('Warehouse'))
                            ->badge(),
                        Infolists\Components\TextEntry::make('created_at')
                            ->label(__('Order Date'))
                            ->dateTime(),
                    ])->columns(3),

                Infolists\Components\Section::make(__('Customer Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('customer_name')
                            ->label(__('Name')),
                        Infolists\Components\TextEntry::make('customer_email')
                            ->label(__('Email'))
                            ->copyable(),
                        Infolists\Components\TextEntry::make('customer_phone')
                            ->label(__('Phone'))
                            ->copyable(),
                        Infolists\Components\TextEntry::make('customer_city')
                            ->label(__('City')),
                        Infolists\Components\TextEntry::make('customer_address')
                            ->label(__('Address'))
                            ->columnSpanFull(),
                    ])->columns(4),

                Infolists\Components\Section::make(__('Payment'))
                    ->schema([
                        Infolists\Components\TextEntry::make('subtotal')
                            ->label(__('Subtotal'))
                            ->money('SAR'),
                        Infolists\Components\TextEntry::make('delivery_fee')
                            ->label(__('Delivery Fee'))
                            ->money('SAR'),
                        Infolists\Components\TextEntry::make('tax_amount')
                            ->label(__('Tax (VAT)'))
                            ->money('SAR'),
                        Infolists\Components\TextEntry::make('total_amount')
                            ->label(__('Total'))
                            ->money('SAR')
                            ->weight('bold')
                            ->size(Infolists\Components\TextEntry\TextEntrySize::Large),
                        Infolists\Components\TextEntry::make('payment_status')
                            ->label(__('Payment Status'))
                            ->badge()
                            ->color(fn (?string $state): string => match ($state) {
                                'paid' => 'success',
                                'pending' => 'warning',
                                'refunded' => 'danger',
                                default => 'gray',
                            }),
                        Infolists\Components\TextEntry::make('payment_method')
                            ->label(__('Payment Method'))
                            ->placeholder('-'),
                    ])->columns(3),

                Infolists\Components\Section::make(__('SAP Integration'))
                    ->schema([
                        Infolists\Components\TextEntry::make('sap_doc_entry')
                            ->label(__('SAP Doc Entry'))
                            ->placeholder(__('Not synced')),
                        Infolists\Components\TextEntry::make('sap_synced_at')
                            ->label(__('Synced At'))
                            ->dateTime()
                            ->placeholder(__('Not synced')),
                    ])->columns(2),

                Infolists\Components\Section::make(__('Order Lines'))
                    ->schema([
                        Infolists\Components\RepeatableEntry::make('lines')
                            ->label('')
                            ->schema([
                                Infolists\Components\TextEntry::make('item_code')
                                    ->label(__('Item Code')),
                                Infolists\Components\TextEntry::make('item_name')
                                    ->label(__('Item Name')),
                                Infolists\Components\TextEntry::make('warehouse_code')
                                    ->label(__('Warehouse')),
                                Infolists\Components\TextEntry::make('quantity')
                                    ->label(__('Qty'))
                                    ->numeric(),
                                Infolists\Components\TextEntry::make('unit_price')
                                    ->label(__('Unit Price'))
                                    ->money('SAR'),
                                Infolists\Components\TextEntry::make('total_price')
                                    ->label(__('Total'))
                                    ->money('SAR'),
                            ])
                            ->columns(6)
                    ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZooboxiOrders::route('/'),
            'view' => Pages\ViewZooboxiOrder::route('/{record}'),
        ];
    }
}
