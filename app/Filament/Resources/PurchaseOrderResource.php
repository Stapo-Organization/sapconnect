<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PurchaseOrderResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\PurchaseOrder;
use App\Models\PaymentPolicy;
use App\Models\Product;
use App\Models\Supplier;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class PurchaseOrderResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = PurchaseOrder::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-cart';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getModelLabel(): string { return __('Purchase Order'); }
    public static function getPluralModelLabel(): string { return __('Purchase Orders'); }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Order Header')
                    ->schema([
                        Forms\Components\Select::make('supplier_id')
                            ->relationship('supplier', 'name')
                            ->searchable()
                            ->preload()
                            ->reactive()
                            ->afterStateUpdated(function (callable $set, $state) {
                                if ($state) {
                                    $supplier = Supplier::find($state);
                                    if ($supplier) {
                                        $set('currency', $supplier->currency);
                                    }
                                } else {
                                    $set('currency', null);
                                }
                                $set('payment_policy_id', null);
                                $set('brand_id', null);
                            })
                            ->required(),

                        Forms\Components\TextInput::make('currency')
                            ->disabled()
                            ->dehydrated()
                            ->required(),

                        Forms\Components\Select::make('payment_policy_id')
                            ->label('Payment Term / Policy')
                            ->options(function (callable $get) {
                                $supplierId = $get('supplier_id');
                                if (! $supplierId) {
                                    return [];
                                }
                                return PaymentPolicy::where('supplier_id', $supplierId)->pluck('name', 'id');
                            })
                            ->required(),

                        Forms\Components\Select::make('brand_id')
                            ->label('Brand (Header)')
                            ->options(function (callable $get) {
                                $supplierId = $get('supplier_id');
                                if ($supplierId) {
                                    $supplier = \App\Models\Supplier::find($supplierId);
                                    if ($supplier && $supplier->brands()->count() > 0) {
                                        return $supplier->brands()->pluck('brands.name', 'brands.id');
                                    }
                                }
                                // Fallback: show all brands if supplier has no brands linked
                                return \App\Models\Brand::pluck('name', 'id');
                            })
                            ->searchable()
                            ->reactive(),

                        Forms\Components\Placeholder::make('brands_display')
                            ->label('Brand(s) from Items')
                            ->content(function ($record) {
                                if (!$record) return '—';
                                
                                $brands = collect($record->lines)
                                    ->map(fn($line) => $line->product?->brand?->name)
                                    ->filter()
                                    ->unique()
                                    ->toArray();
                                    
                                return empty($brands) ? '—' : implode(', ', $brands);
                            })
                            ->visible(fn ($record) => $record !== null),

                        Forms\Components\TextInput::make('pq_ref')
                            ->label('PQ Reference')
                            ->maxLength(255),

                        Forms\Components\TextInput::make('pq_value')
                            ->label('PQ Value')
                            ->numeric(),

                        Forms\Components\DatePicker::make('est_departure')
                            ->label('Est. Departure date'),

                        Forms\Components\TextInput::make('factory_name')
                            ->label('Linked Factory Info')
                            ->maxLength(255),
                            
                        Forms\Components\Fieldset::make('SAP Info (Auto Sync)')
                            ->schema([
                                Forms\Components\TextInput::make('sap_doc_entry')
                                    ->label('SAP DocEntry')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('sap_doc_num')
                                    ->label('SAP Doc#')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('po_number')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('po_value')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('doc_status')
                                    ->label('SAP Status')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('sync_status')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\DatePicker::make('doc_date')
                                    ->label('SAP Doc Date')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\DatePicker::make('doc_due_date')
                                    ->label('SAP Due Date')
                                    ->disabled()
                                    ->dehydrated(false),
                            ])
                            ->columns(4),
                    ])->columns(2),

                Forms\Components\Section::make('Order Lines (Items)')
                    ->schema([
                        Forms\Components\Repeater::make('lines')
                            ->relationship()
                            ->schema([
                                 Forms\Components\Select::make('product_id')
                                    ->label('SKU (Product)')
                                    ->relationship('product', 'item_name')
                                    ->searchable()
                                    ->preload()
                                    ->reactive()
                                    ->afterStateUpdated(function (callable $set, $state) {
                                        if ($state) {
                                            $product = Product::find($state);
                                            if ($product) {
                                                $set('description', $product->item_name);
                                            }
                                        }
                                    }),

                                Forms\Components\TextInput::make('item_code')
                                    ->label('SAP Item Code')
                                    ->disabled()
                                    ->dehydrated(false)
                                    ->visible(fn ($record) => $record && $record->item_code),
                                
                                Forms\Components\TextInput::make('description')
                                    ->maxLength(255),

                                Forms\Components\TextInput::make('quantity')
                                    ->numeric()
                                    ->default(1)
                                    ->required()
                                    ->reactive()
                                    ->afterStateUpdated(fn (callable $set, callable $get) => $set('total_price', (float)$get('quantity') * (float)$get('unit_price')))
                                    ->minValue(1),

                                Forms\Components\TextInput::make('unit_price')
                                    ->numeric()
                                    ->default(0)
                                    ->required()
                                    ->reactive()
                                    ->afterStateUpdated(fn (callable $set, callable $get) => $set('total_price', (float)$get('quantity') * (float)$get('unit_price'))),
                                
                                Forms\Components\TextInput::make('total_price')
                                    ->numeric()
                                    ->disabled()
                                    ->dehydrated()
                                    ->required(),

                                Forms\Components\TextInput::make('pallet_quantity')
                                    ->numeric()
                                    ->label('Pallets (Optional)'),
                            ])
                            ->columns(3)
                            ->defaultItems(1),
                    ]),
            ]);
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        return parent::getEloquentQuery()->with(['supplier', 'brand', 'lines.product.brand']);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('sap_doc_num')
                    ->label('SAP Doc#')
                    ->sortable()
                    ->searchable()
                    ->default('—'),
                Tables\Columns\TextColumn::make('supplier.name')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('brands')
                    ->label('Brand(s)')
                    ->badge()
                    ->color('info')
                    ->getStateUsing(function (PurchaseOrder $record) {
                        if ($record->brand_id && $record->brand) {
                            return [$record->brand->name];
                        }
                        return collect($record->lines)
                            ->map(fn($line) => $line->product?->brand?->name)
                            ->filter()
                            ->unique()
                            ->toArray();
                    })
                    ->default('—'),
                Tables\Columns\TextColumn::make('currency'),
                Tables\Columns\TextColumn::make('po_value')
                    ->label('PO Value')
                    ->money(fn ($record) => $record->currency ?? 'SAR')
                    ->sortable(),
                Tables\Columns\TextColumn::make('doc_date')
                    ->label('Doc Date')
                    ->date()
                    ->sortable(),
                Tables\Columns\BadgeColumn::make('doc_status')
                    ->label('SAP Status')
                    ->colors([
                        'success' => 'Open',
                        'gray' => 'Closed',
                        'warning' => 'Delivered',
                        'info' => 'Paid',
                    ])
                    ->default('—'),
                Tables\Columns\BadgeColumn::make('sync_status')
                    ->colors([
                        'warning' => 'pending',
                        'success' => 'synced',
                        'danger' => 'failed',
                    ]),
                Tables\Columns\TextColumn::make('shipment_progress')
                    ->label('Shipment Progress')
                    ->getStateUsing(function ($record): string {
                        $analytics = new \App\Services\PurchaseOrderAnalytics();
                        $progress = $analytics->getShipmentProgress($record);
                        return "{$progress['shipped_percentage']}%";
                    })
                    ->badge()
                    ->color(function ($state): string {
                        $pct = (int) $state;
                        if ($pct >= 100) return 'success';
                        if ($pct >= 50) return 'info';
                        if ($pct > 0) return 'warning';
                        return 'gray';
                    })
                    ->tooltip('Shipped vs Ordered quantity'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('supplier_id')
                    ->relationship('supplier', 'name')
                    ->searchable()
                    ->preload()
                    ->label('Supplier'),
                Tables\Filters\SelectFilter::make('brand_id')
                    ->relationship('brand', 'name')
                    ->searchable()
                    ->preload()
                    ->label('Brand'),
                Tables\Filters\SelectFilter::make('doc_status')
                    ->options([
                        'Open' => 'Open',
                        'Closed' => 'Closed',
                        'Delivered' => 'Delivered',
                        'Paid' => 'Paid',
                    ])
                    ->label('SAP Status'),
                Tables\Filters\SelectFilter::make('sync_status')
                    ->options([
                        'pending' => 'Pending',
                        'synced' => 'Synced',
                        'failed' => 'Failed',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
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
            'index' => Pages\ListPurchaseOrders::route('/'),
            'create' => Pages\CreatePurchaseOrder::route('/create'),
            'edit' => Pages\EditPurchaseOrder::route('/{record}/edit'),
        ];
    }
}
