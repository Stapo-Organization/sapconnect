<?php

namespace App\Filament\Resources;

use App\Filament\Resources\LandedCostResource\Pages;
use App\Models\LandedCost;
use App\Models\PurchaseOrder;
use App\Models\Product;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class LandedCostResource extends Resource
{
    protected static ?string $model = LandedCost::class;

    protected static ?string $navigationIcon = 'heroicon-o-calculator';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getModelLabel(): string { return __('Landed Cost'); }
    public static function getPluralModelLabel(): string { return __('Landed Costs'); }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                // ─── Header Section ───
                Forms\Components\Section::make('PO & Cost Parameters')
                    ->description('Select PO, set exchange rate, and enter additional costs. Then use "Import from PO" to load items.')
                    ->schema([
                        Forms\Components\Select::make('purchase_order_id')
                            ->label('Purchase Order')
                            ->options(function () {
                                return PurchaseOrder::with('supplier')
                                    ->orderByDesc('id')
                                    ->limit(200)
                                    ->get()
                                    ->mapWithKeys(fn ($po) => [
                                        $po->id => "PO #{$po->po_number} — {$po->supplier?->name} ({$po->currency})"
                                    ]);
                            })
                            ->searchable()
                            ->required()
                            ->disabled(fn (string $operation): bool => $operation === 'edit')
                            ->reactive(),

                        Forms\Components\Select::make('shipment_id')
                            ->label('Linked Shipment (Optional)')
                            ->relationship('shipment', 'id')
                            ->searchable()
                            ->placeholder('Link to existing shipment'),

                        Forms\Components\TextInput::make('exchange_rate')
                            ->numeric()
                            ->required()
                            ->default(3.7500)
                            ->step(0.0001)
                            ->label('Exchange Rate (to SAR)')
                            ->helperText('Currency → SAR conversion rate'),

                        Forms\Components\TextInput::make('vat_percentage')
                            ->numeric()
                            ->required()
                            ->default(15.00)
                            ->suffix('%')
                            ->label('VAT %'),
                    ])->columns(4),

                Forms\Components\Section::make('Additional Costs (Manual Input)')
                    ->schema([
                        Forms\Components\TextInput::make('shipping_cost_foreign')
                            ->numeric()
                            ->default(0)
                            ->label('Total Shipping (Supplier Currency)')
                            ->helperText('From freight invoice'),

                        Forms\Components\TextInput::make('customs_cost')
                            ->numeric()
                            ->default(0)
                            ->prefix('SAR')
                            ->label('Customs Declaration Cost'),

                        Forms\Components\TextInput::make('broker_cost')
                            ->numeric()
                            ->default(0)
                            ->prefix('SAR')
                            ->label('Broker / Clearance Cost'),

                        Forms\Components\Placeholder::make('shipping_cost_sar_display')
                            ->label('Total Shipping (SAR)')
                            ->content(fn ($record) => $record
                                ? number_format((float) $record->shipping_cost_foreign * (float) $record->exchange_rate, 2) . ' SAR'
                                : '—'),

                        Forms\Components\Placeholder::make('total_additional_display')
                            ->label('Total Additional Costs')
                            ->content(fn ($record) => $record
                                ? number_format((float) $record->total_additional_costs, 2) . ' SAR'
                                : '—'),
                    ])->columns(3),

                // ─── Status ───
                Forms\Components\Section::make('Status')
                    ->schema([
                        Forms\Components\Select::make('preparation_status')
                            ->options([
                                'draft' => '📝 Draft',
                                'ready' => '✅ Ready',
                            ])
                            ->default('draft'),

                        Forms\Components\Select::make('pricing_status')
                            ->label('Prices Updated? (تحديث الأسعار)')
                            ->options([
                                'pending' => '⏳ Pending',
                                'ready'   => '✅ Priced',
                                'done'    => '✅ Done',
                                'no_need' => '➖ No Need',
                            ])
                            ->default('pending'),

                        Forms\Components\Textarea::make('remarks')
                            ->columnSpanFull(),
                    ])->columns(2),

                // ─── Product Lines (Repeater) ───
                Forms\Components\Section::make('Product Cost Lines')
                    ->description('Each row calculates: Unit Cost SAR = (Unit Price + Shipping Allocation) × Exchange Rate. Use "Import from PO" after saving header.')
                    ->schema([
                        Forms\Components\Repeater::make('lines')
                            ->relationship()
                            ->schema([
                                Forms\Components\Select::make('product_id')
                                    ->label('Product')
                                    ->options(Product::pluck('item_name', 'id'))
                                    ->searchable()
                                    ->columnSpan(2),

                                Forms\Components\TextInput::make('quantity')
                                    ->numeric()
                                    ->required()
                                    ->minValue(1),

                                Forms\Components\TextInput::make('unit_price_foreign')
                                    ->numeric()
                                    ->required()
                                    ->label('Unit Price (Foreign)'),

                                Forms\Components\TextInput::make('total_value_foreign')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('Total Value'),

                                Forms\Components\TextInput::make('value_participate_pct')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('Participate %')
                                    ->suffix('%'),

                                Forms\Components\TextInput::make('shipping_per_unit')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('Ship/Unit'),

                                Forms\Components\TextInput::make('unit_cost_sar')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('Cost SAR')
                                    ->prefix('SAR'),

                                Forms\Components\TextInput::make('unit_cost_sar_with_vat')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('Cost+VAT')
                                    ->prefix('SAR'),

                                Forms\Components\TextInput::make('wholesale_price')
                                    ->numeric()
                                    ->label('Wholesale')
                                    ->helperText('Manual input'),

                                Forms\Components\TextInput::make('gross_profit_pct')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('GP%')
                                    ->suffix('%'),

                                Forms\Components\TextInput::make('profit_per_unit_sar')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->label('Profit/Unit')
                                    ->prefix('SAR'),

                                Forms\Components\TextInput::make('old_sales_price')
                                    ->numeric()
                                    ->label('Old Price'),

                                Forms\Components\TextInput::make('new_price')
                                    ->numeric()
                                    ->label('New Price'),

                                Forms\Components\TextInput::make('remark')
                                    ->label('Remark'),
                            ])
                            ->columns(5)
                            ->defaultItems(0)
                            ->addActionLabel('Add Product Line')
                            ->collapsible()
                            ->itemLabel(fn (array $state): ?string =>
                                ($state['product_id'] ?? null)
                                    ? Product::find($state['product_id'])?->item_name
                                    : 'New Line'
                            ),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->sortable()
                    ->label('#'),
                Tables\Columns\TextColumn::make('purchaseOrder.po_number')
                    ->label('PO Number')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('purchaseOrder.supplier.name')
                    ->label('Supplier')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('exchange_rate')
                    ->label('Rate')
                    ->numeric(4),
                Tables\Columns\TextColumn::make('shipping_cost_sar')
                    ->label('Shipping (SAR)')
                    ->money('SAR'),
                Tables\Columns\TextColumn::make('total_additional_costs')
                    ->label('Total Add. Costs')
                    ->money('SAR'),
                Tables\Columns\TextColumn::make('lines_count')
                    ->counts('lines')
                    ->label('Items'),
                Tables\Columns\BadgeColumn::make('preparation_status')
                    ->colors([
                        'gray' => 'draft',
                        'success' => 'ready',
                    ]),
                Tables\Columns\BadgeColumn::make('pricing_status')
                    ->colors([
                        'warning' => 'pending',
                        'success' => fn ($state) => in_array($state, ['ready', 'done']),
                        'gray'    => 'no_need',
                    ]),
                Tables\Columns\TextColumn::make('created_at')
                    ->date()
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('preparation_status')
                    ->options([
                        'draft' => 'Draft',
                        'ready' => 'Ready',
                    ]),
                Tables\Filters\SelectFilter::make('pricing_status')
                    ->options([
                        'pending' => 'Pending',
                        'ready'   => 'Priced',
                        'done'    => 'Done',
                        'no_need' => 'No Need',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\Action::make('calculate')
                    ->label('🔄 Calculate')
                    ->icon('heroicon-o-calculator')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->action(function (LandedCost $record) {
                        $calculator = new \App\Services\LandedCostCalculator();
                        $calculator->calculate($record);
                        \Filament\Notifications\Notification::make()
                            ->title('Calculation Complete')
                            ->body("All {$record->lines()->count()} lines recalculated.")
                            ->success()
                            ->send();
                    }),
                Tables\Actions\Action::make('import_po')
                    ->label('📥 Import from PO')
                    ->icon('heroicon-o-arrow-down-tray')
                    ->color('info')
                    ->requiresConfirmation()
                    ->action(function (LandedCost $record) {
                        $calculator = new \App\Services\LandedCostCalculator();
                        $count = $calculator->importFromPurchaseOrder($record);
                        \Filament\Notifications\Notification::make()
                            ->title('Import Complete')
                            ->body("{$count} lines imported from PO #{$record->purchaseOrder?->po_number}.")
                            ->success()
                            ->send();
                    }),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListLandedCosts::route('/'),
            'create' => Pages\CreateLandedCost::route('/create'),
            'edit' => Pages\EditLandedCost::route('/{record}/edit'),
        ];
    }
}
