<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PurchaseOrderResource\Pages;
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
    protected static ?string $model = PurchaseOrder::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-cart';
    protected static ?string $navigationGroup = 'Supply Chain';
    protected static ?string $modelLabel = 'Purchase Order (Staging)';
    protected static ?string $pluralModelLabel = 'Purchase Orders';

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
                            ->relationship('brand', 'name')
                            ->searchable()
                            ->preload(),

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
                                Forms\Components\TextInput::make('po_number')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('po_value')
                                    ->disabled()
                                    ->dehydrated(false),
                                Forms\Components\TextInput::make('sync_status')
                                    ->disabled()
                                    ->dehydrated(false),
                            ])
                            ->columns(3),
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
                                    })
                                    ->required(),
                                
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

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('Internal ID')
                    ->sortable()
                    ->searchable(),
                Tables\Columns\TextColumn::make('supplier.name')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('currency'),
                Tables\Columns\TextColumn::make('paymentPolicy.name')
                    ->label('Payment Policy'),
                Tables\Columns\TextColumn::make('pq_value')
                    ->money(fn ($record) => $record->currency ?? 'SAR'),
                Tables\Columns\BadgeColumn::make('sync_status')
                    ->colors([
                        'warning' => 'pending',
                        'success' => 'synced',
                        'danger' => 'failed',
                    ]),
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                //
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
