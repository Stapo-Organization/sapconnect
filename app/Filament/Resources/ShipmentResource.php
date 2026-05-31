<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ShipmentResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Broker;
use App\Models\Forwarder;
use App\Models\PurchaseOrderLine;
use App\Models\Shipment;
use App\Models\Warehouse;
use App\Services\ShipmentQuantityGuard;
use Closure;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ShipmentResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = Shipment::class;

    protected static ?string $navigationIcon = 'heroicon-o-truck';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getModelLabel(): string { return __('Shipment'); }
    public static function getPluralModelLabel(): string { return __('Shipments'); }

    /**
     * Centralized shipment statuses matching real-world workflow.
     */
    public static function getStatusOptions(): array
    {
        return [
            'container_booking' => '📦 Container Booking',
            'loading'           => '🏗️ Loading',
            'shipped'           => '🚢 Shipped',
            'in_transit'        => '🌊 In Transit',
            'arrived_port'      => '⚓ Arrived at Port',
            'under_inspection'  => '🔍 Under Inspection',
            'duty_paid'         => '💰 Duty Paid',
            'clearance'         => '📋 Customs Clearance',
            'out_for_delivery'  => '🚛 Out for Delivery',
            'received_warehouse'=> '✅ Received at Warehouse',
            'delivered'         => '🏁 Delivered',
        ];
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                // ─── Section 1: Core Details ───
                Forms\Components\Section::make('Shipment Details')
                    ->schema([
                        Forms\Components\Select::make('purchase_order_id')
                            ->relationship('purchaseOrder', 'id')
                            ->label('Parent PO')
                            ->searchable()
                            ->preload()
                            ->required()
                            ->disabled(fn (string $operation): bool => $operation === 'edit'),

                        Forms\Components\Select::make('status')
                            ->options(static::getStatusOptions())
                            ->default('container_booking')
                            ->required()
                            ->reactive()
                            ->helperText('Changing status triggers financial alerts based on Payment Policies.'),

                        Forms\Components\Toggle::make('is_announced')
                            ->label('Announced (ASN received)'),

                        Forms\Components\TextInput::make('order_description')
                            ->label('Order Description')
                            ->placeholder('e.g., TUNA WITH-400G')
                            ->maxLength(255),
                    ])->columns(4),

                // ─── Section 2: Transport & Route ───
                Forms\Components\Section::make('Transport & Route')
                    ->schema([
                        Forms\Components\Select::make('forwarder_id')
                            ->label('Forwarder')
                            ->options(Forwarder::where('is_active', true)->pluck('name', 'id'))
                            ->searchable()
                            ->placeholder('Select forwarder'),

                        Forms\Components\Select::make('broker_id')
                            ->label('Customs Broker')
                            ->options(Broker::where('is_active', true)->pluck('name', 'id'))
                            ->searchable()
                            ->placeholder('Select broker'),

                        Forms\Components\Select::make('transport_mode')
                            ->options([
                                'sea' => '🚢 Sea (Ocean)',
                                'air' => '✈️ Air',
                                'land' => '🚛 Land',
                            ]),

                        Forms\Components\Select::make('shipment_terms')
                            ->label('Incoterms')
                            ->options([
                                'FOB' => 'FOB (Free on Board)',
                                'CIF' => 'CIF (Cost, Insurance & Freight)',
                                'FCA' => 'FCA (Free Carrier)',
                                'EXW' => 'EXW (Ex Works)',
                                'CFR' => 'CFR (Cost & Freight)',
                                'DDP' => 'DDP (Delivered Duty Paid)',
                            ])
                            ->searchable(),

                        Forms\Components\TextInput::make('country_of_origin')
                            ->label('Country of Origin')
                            ->placeholder('e.g., THAILAND'),

                        Forms\Components\TextInput::make('origin_port')
                            ->label('Origin Port/City')
                            ->placeholder('e.g., SONGKHLA'),

                        Forms\Components\Select::make('storage_location_id')
                            ->label('Target Warehouse')
                            ->options(Warehouse::pluck('warehouse_name', 'id'))
                            ->searchable(),

                        Forms\Components\TextInput::make('mbl')
                            ->label('MBL (Master Bill of Lading)'),

                        Forms\Components\TextInput::make('hbl')
                            ->label('HBL (House Bill of Lading)'),
                    ])->columns(3),

                // ─── Section 3: Dates ───
                Forms\Components\Section::make('Key Dates')
                    ->schema([
                        Forms\Components\DatePicker::make('etd')
                            ->label('ETD (Departure)'),

                        Forms\Components\DatePicker::make('eta')
                            ->label('ETA (Arrival)'),

                        Forms\Components\DatePicker::make('received_date')
                            ->label('Received Date (Actual)')
                            ->helperText('Date goods physically received at warehouse'),

                        Forms\Components\Placeholder::make('days_until_arrival')
                            ->label('Days Until Arrival')
                            ->content(function ($record) {
                                if (!$record || !$record->eta) return '—';
                                $days = $record->days_until_arrival;
                                if ($days < 0) return "⚠️ Overdue by " . abs($days) . " days";
                                if ($days === 0) return "📍 Arriving today";
                                return "⏳ {$days} days remaining";
                            }),
                    ])->columns(4),

                // ─── Section 4: Shipment Lines (Partial Shipment) ───
                Forms\Components\Section::make('Shipment Lines (Partial Shipment Tracking)')
                    ->schema([
                        Forms\Components\Repeater::make('shipmentLines')
                            ->relationship()
                            ->schema([
                                Forms\Components\Select::make('purchase_order_line_id')
                                    ->label('PO Line Item')
                                    ->options(function (callable $get) {
                                        $poId = $get('../../purchase_order_id');
                                        if (!$poId) return [];
                                        return PurchaseOrderLine::where('purchase_order_id', $poId)
                                            ->get()
                                            ->mapWithKeys(fn ($line) => [
                                                $line->id => "{$line->product?->item_name} (Ordered: {$line->quantity})"
                                            ]);
                                    })
                                    ->required()
                                    ->searchable(),
                                Forms\Components\TextInput::make('shipped_quantity')
                                    ->numeric()
                                    ->required()
                                    ->minValue(1)
                                    ->rule(function (callable $get) {
                                        return function (string $attribute, $value, Closure $fail) use ($get) {
                                            $poLineId = $get('purchase_order_line_id');
                                            if (!$poLineId || !$value) return;
                                            $guard = new ShipmentQuantityGuard();
                                            $result = $guard->validate((int) $poLineId, (int) $value);
                                            if (!$result['valid']) {
                                                $fail($result['message']);
                                            }
                                        };
                                    }),
                                Forms\Components\TextInput::make('notes')
                                    ->maxLength(255),
                            ])
                            ->columns(3)
                            ->defaultItems(0)
                            ->addActionLabel('Add Line Item'),
                    ])
                    ->collapsible(),

                // ─── Section 5: Containers & Cost ───
                Forms\Components\Section::make('Containers & Cost')
                    ->schema([
                        Forms\Components\Repeater::make('containers')
                            ->relationship()
                            ->schema([
                                Forms\Components\Select::make('container_type')
                                    ->options([
                                        '20ft' => "20' Standard",
                                        '40ft' => "40' Standard",
                                        '40hq' => "40' HQ",
                                        'LCL' => 'LCL',
                                        'Air Cargo' => 'Air Cargo',
                                    ]),
                                Forms\Components\TextInput::make('container_number')
                                    ->placeholder('e.g., FFAU3779746'),
                                Forms\Components\TextInput::make('pallet_count')
                                    ->numeric()
                                    ->default(0),
                                Forms\Components\TextInput::make('freight_cost')
                                    ->numeric()
                                    ->default(0)
                                    ->prefix(fn (callable $get) => $get('../../../../currency') ?? $get('../../../currency') ?? 'SAR')
                                    ->reactive()
                                    ->afterStateUpdated(function (callable $set, callable $get, $state) {
                                    }),
                            ])
                            ->columns(4)
                            ->defaultItems(1)
                            ->reactive()
                            ->afterStateUpdated(function (callable $set, callable $get, $state) {
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
                            ->dehydrated()
                            ->label('Total Freight Cost'),
                    ])
                    ->collapsible(),

                // ─── Section 6: Customs & Clearance (NEW) ───
                Forms\Components\Section::make('Customs & Clearance')
                    ->schema([
                        Forms\Components\TextInput::make('customs_manifest_no')
                            ->label('Customs Manifest No. (رقم البيان)')
                            ->placeholder('e.g., 93087'),

                        Forms\Components\TextInput::make('freight_invoice_no')
                            ->label('Freight Invoice No.'),

                        Forms\Components\TextInput::make('freight_invoice_amount')
                            ->numeric()
                            ->label('Freight Invoice Amount')
                            ->prefix(fn ($record) => $record?->purchaseOrder?->currency ?? 'SAR'),

                        Forms\Components\TextInput::make('clearance_invoice_no')
                            ->label('Clearance Invoice No.'),

                        Forms\Components\TextInput::make('clearance_amount')
                            ->numeric()
                            ->label('Clearance Amount')
                            ->prefix('SAR'),

                        Forms\Components\TextInput::make('exchange_rate')
                            ->numeric()
                            ->label('Exchange Rate')
                            ->placeholder('e.g., 3.76')
                            ->helperText('Currency to SAR conversion rate'),
                    ])->columns(3)
                    ->collapsible(),

                // ─── Section 7: Notes ───
                Forms\Components\Section::make('Notes & Remarks')
                    ->schema([
                        Forms\Components\Textarea::make('remarks')
                            ->label('Remarks'),
                        Forms\Components\Textarea::make('notes')
                            ->label('Additional Notes'),
                    ])->columns(2)
                    ->collapsible()
                    ->collapsed(),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')->sortable(),
                Tables\Columns\TextColumn::make('purchaseOrder.supplier.name')
                    ->label('Supplier')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('order_description')
                    ->label('Description')
                    ->limit(30)
                    ->searchable(),
                Tables\Columns\BadgeColumn::make('status')
                    ->colors([
                        'gray' => 'container_booking',
                        'warning' => 'loading',
                        'primary' => 'shipped',
                        'info' => fn ($state) => in_array($state, ['in_transit', 'arrived_port']),
                        'warning' => fn ($state) => in_array($state, ['under_inspection', 'duty_paid', 'clearance']),
                        'success' => fn ($state) => in_array($state, ['received_warehouse', 'delivered', 'out_for_delivery']),
                    ])
                    ->formatStateUsing(fn ($state) => static::getStatusOptions()[$state] ?? $state),
                Tables\Columns\IconColumn::make('is_announced')
                    ->boolean()
                    ->label('ASN'),
                Tables\Columns\TextColumn::make('transport_mode')
                    ->badge(),
                Tables\Columns\TextColumn::make('country_of_origin')
                    ->label('Origin')
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('etd')
                    ->date()
                    ->sortable()
                    ->label('ETD'),
                Tables\Columns\TextColumn::make('eta')
                    ->date()
                    ->sortable()
                    ->label('ETA'),
                Tables\Columns\TextColumn::make('days_until_arrival')
                    ->label('Arriving In')
                    ->getStateUsing(function (Shipment $record): string {
                        $days = $record->days_until_arrival;
                        if ($days === null) return '—';
                        if ($days < 0) return abs($days) . 'd overdue';
                        if ($days === 0) return 'Today';
                        return $days . ' days';
                    })
                    ->color(function (Shipment $record): string {
                        $days = $record->days_until_arrival;
                        if ($days === null) return 'gray';
                        if ($days < 0) return 'danger';
                        if ($days <= 7) return 'warning';
                        return 'success';
                    })
                    ->badge(),
                Tables\Columns\TextColumn::make('forwarder.name')
                    ->label('Forwarder')
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('storageLocation.warehouse_name')
                    ->label('Warehouse')
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('total_freight_cost')
                    ->money(fn ($record) => $record->purchaseOrder?->currency ?? 'SAR')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('eta', 'asc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options(static::getStatusOptions())
                    ->multiple(),
                Tables\Filters\SelectFilter::make('transport_mode')
                    ->options([
                        'sea' => 'Sea',
                        'air' => 'Air',
                        'land' => 'Land',
                    ]),
                Tables\Filters\SelectFilter::make('forwarder_id')
                    ->relationship('forwarder', 'name')
                    ->label('Forwarder')
                    ->searchable()
                    ->preload(),
                Tables\Filters\SelectFilter::make('storage_location_id')
                    ->relationship('storageLocation', 'warehouse_name')
                    ->label('Warehouse')
                    ->searchable()
                    ->preload(),
                Tables\Filters\Filter::make('arriving_soon')
                    ->label('Arriving within 7 days')
                    ->query(fn (Builder $query) => $query
                        ->whereNotNull('eta')
                        ->where('eta', '>=', now())
                        ->where('eta', '<=', now()->addDays(7))
                    ),
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
