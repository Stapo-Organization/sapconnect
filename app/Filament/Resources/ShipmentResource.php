<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ShipmentResource\Pages;
use App\Models\Shipment;
use App\Models\Warehouse;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ShipmentResource extends Resource
{
    protected static ?string $model = Shipment::class;

    protected static ?string $navigationIcon = 'heroicon-o-truck';
    protected static ?string $navigationGroup = 'Supply Chain';
    protected static ?string $modelLabel = 'Shipment';
    protected static ?string $pluralModelLabel = 'Shipments';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Shipment Details')
                    ->schema([
                        Forms\Components\Select::make('purchase_order_id')
                            ->relationship('purchaseOrder', 'id') // Internal ID
                            ->label('Parent PO')
                            ->searchable()
                            ->preload()
                            ->required()
                            ->disabled(fn (string $operation): bool => $operation === 'edit'),
                            
                        Forms\Components\Select::make('status')
                            ->options([
                                'scheduled' => 'Scheduled',
                                'shipped' => 'Shipped',
                                'arrived_port' => 'Arrived at Port',
                                'delivered' => 'Delivered',
                            ])
                            ->default('scheduled')
                            ->required()
                            ->reactive()
                            ->helperText('Changing status will trigger financial alerts based on Payment Policies.'),
                        
                        Forms\Components\Toggle::make('is_announced')
                            ->label('Is Announced (ASN received)'),
                    ])->columns(3),

                Forms\Components\Section::make('Transport & Route')
                    ->schema([
                        Forms\Components\TextInput::make('forwarder_name')
                            ->label('Forwarder'),
                            
                        Forms\Components\Select::make('transport_mode')
                            ->options([
                                'sea' => 'Sea',
                                'air' => 'Air',
                                'land' => 'Land',
                            ]),
                            
                        Forms\Components\TextInput::make('origin_port')
                            ->label('Origin Port'),
                            
                        Forms\Components\Select::make('storage_location_id')
                            ->label('Target Warehouse')
                            ->options(Warehouse::pluck('name', 'id'))
                            ->searchable(),
                            
                        Forms\Components\TextInput::make('mbl')
                            ->label('MBL (Master Bill of Lading)'),
                            
                        Forms\Components\TextInput::make('hbl')
                            ->label('HBL (House Bill of Lading)'),
                            
                        Forms\Components\DatePicker::make('etd')
                            ->label('ETD (Departure)'),
                            
                        Forms\Components\DatePicker::make('eta')
                            ->label('ETA (Arrival)'),
                    ])->columns(4),

                Forms\Components\Section::make('Containers & Cost')
                    ->schema([
                        Forms\Components\Repeater::make('containers')
                            ->relationship()
                            ->schema([
                                Forms\Components\Select::make('container_type')
                                    ->options([
                                        '20ft' => '20ft',
                                        '40ft' => '40ft',
                                        'LCL' => 'LCL',
                                        'Air Cargo' => 'Air Cargo'
                                    ]),
                                Forms\Components\TextInput::make('container_number'),
                                Forms\Components\TextInput::make('pallet_count')
                                    ->numeric()
                                    ->default(0),
                                Forms\Components\TextInput::make('freight_cost')
                                    ->numeric()
                                    ->default(0)
                                    ->prefix('SAR')
                                    ->reactive()
                                    ->afterStateUpdated(function (callable $set, callable $get, $state) {
                                        // The total_freight_cost can be computed dynamically but since Repeater state lives inside 'containers',
                                        // It's cleaner to handle the summing in the Model/Observer or before save, or by traversing get('../../containers').
                                    }),
                            ])
                            ->columns(4)
                            ->defaultItems(1)
                            ->reactive()
                            ->afterStateUpdated(function (callable $set, callable $get, $state) {
                                // Calculate total freight cost on state changes
                                $total = 0;
                                if(is_array($state)) {
                                    foreach($state as $container) {
                                        $total += (float) ($container['freight_cost'] ?? 0);
                                    }
                                }
                                $set('total_freight_cost', $total);
                            }),
                            
                        Forms\Components\TextInput::make('total_freight_cost')
                            ->numeric()
                            ->disabled()
                            ->dehydrated(false) // We will compute and save it in backend explicitly or leave it if computed from repeater. Let's dehydrated(true) and calculate correctly.
                            ->dehydrated()
                            ->label('Total Freight Cost'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')->sortable(),
                Tables\Columns\TextColumn::make('purchaseOrder.id')->label('PO ID')->searchable(),
                Tables\Columns\BadgeColumn::make('status')
                    ->colors([
                        'warning' => 'scheduled',
                        'primary' => 'shipped',
                        'success' => 'arrived_port',
                        'success' => 'delivered',
                    ]),
                Tables\Columns\IconColumn::make('is_announced')
                    ->boolean(),
                Tables\Columns\TextColumn::make('transport_mode'),
                Tables\Columns\TextColumn::make('eta')
                    ->date()
                    ->sortable(),
                Tables\Columns\TextColumn::make('total_freight_cost')
                    ->money('SAR'),
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
            'index' => Pages\ListShipments::route('/'),
            'create' => Pages\CreateShipment::route('/create'),
            'edit' => Pages\EditShipment::route('/{record}/edit'),
        ];
    }
}
