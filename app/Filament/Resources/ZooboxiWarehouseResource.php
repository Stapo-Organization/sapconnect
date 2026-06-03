<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZooboxiWarehouseResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\ZooboxiWarehouse;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Filament\Infolists;
use Filament\Infolists\Infolist;

class ZooboxiWarehouseResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = ZooboxiWarehouse::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';

    protected static ?string $slug = 'zooboxi-warehouses';

    public static function getNavigationLabel(): string
    {
        return __('Zooboxi Warehouses');
    }

    public static function getModelLabel(): string
    {
        return __('Warehouse');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Zooboxi Warehouses');
    }

    public static function getNavigationGroup(): ?string
    {
        return '🛒 Zooboxi Store';
    }

    protected static ?int $navigationSort = 2;

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::where('is_active', true)->count();
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'info';
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Warehouse Details'))
                    ->schema([
                        Forms\Components\TextInput::make('warehouse_code')
                            ->label(__('Warehouse Code'))
                            ->required()
                            ->disabled()
                            ->maxLength(20),
                        Forms\Components\TextInput::make('display_name_ar')
                            ->label(__('Display Name (AR)'))
                            ->required()
                            ->maxLength(255),
                        Forms\Components\TextInput::make('display_name_en')
                            ->label(__('Display Name (EN)'))
                            ->maxLength(255),
                        Forms\Components\TextInput::make('city')
                            ->label(__('City'))
                            ->required()
                            ->maxLength(100),
                        Forms\Components\Textarea::make('address_ar')
                            ->label(__('Address (AR)'))
                            ->maxLength(500),
                        Forms\Components\Textarea::make('address_en')
                            ->label(__('Address (EN)'))
                            ->maxLength(500),
                        Forms\Components\TextInput::make('phone')
                            ->label(__('Phone'))
                            ->tel()
                            ->maxLength(20),
                    ])->columns(2),

                Forms\Components\Section::make(__('SAP Integration'))
                    ->schema([
                        Forms\Components\TagsInput::make('sap_warehouse_codes')
                            ->label(__('SAP Warehouse Codes'))
                            ->helperText(__('SAP warehouse codes that map to this Zooboxi warehouse'))
                            ->placeholder(__('Add SAP code...'))
                            ->columnSpanFull(),
                    ]),

                Forms\Components\Section::make(__('Location & Delivery'))
                    ->schema([
                        Forms\Components\TextInput::make('latitude')
                            ->label(__('Latitude'))
                            ->numeric()
                            ->step(0.000001),
                        Forms\Components\TextInput::make('longitude')
                            ->label(__('Longitude'))
                            ->numeric()
                            ->step(0.000001),
                        Forms\Components\TextInput::make('express_radius_km')
                            ->label(__('Express Delivery Radius (km)'))
                            ->numeric()
                            ->step(0.1)
                            ->suffix('km')
                            ->helperText(__('Maximum radius for express delivery (2-hour)')),
                    ])->columns(3),

                Forms\Components\Section::make(__('Settings'))
                    ->schema([
                        Forms\Components\Toggle::make('is_active')
                            ->label(__('Active'))
                            ->default(true),
                        Forms\Components\Toggle::make('is_central')
                            ->label(__('Central Warehouse'))
                            ->helperText(__('Central warehouses are used for same-day delivery')),
                        Forms\Components\Toggle::make('is_main_hub')
                            ->label(__('Main Hub'))
                            ->helperText(__('Main hub for the region')),
                        Forms\Components\Toggle::make('is_pickup_enabled')
                            ->label(__('Click & Collect'))
                            ->helperText(__('Allow customers to pick up orders from this branch')),
                    ])->columns(4),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label(__('Code'))
                    ->searchable()
                    ->sortable()
                    ->weight('bold')
                    ->copyable(),

                Tables\Columns\TextColumn::make('display_name_ar')
                    ->label(__('Name (AR)'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('city')
                    ->label(__('City'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'Riyadh' => 'success',
                        'Jeddah' => 'info',
                        default => 'gray',
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('express_radius_km')
                    ->label(__('Express Radius'))
                    ->suffix(' km')
                    ->numeric(1)
                    ->alignCenter()
                    ->color('warning'),

                Tables\Columns\TextColumn::make('sap_codes_count')
                    ->label(__('SAP Codes'))
                    ->state(fn (ZooboxiWarehouse $record) => count($record->sap_warehouse_codes ?? []))
                    ->badge()
                    ->color('primary')
                    ->alignCenter(),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('Active'))
                    ->boolean()
                    ->alignCenter(),

                Tables\Columns\IconColumn::make('is_central')
                    ->label(__('Central'))
                    ->boolean()
                    ->alignCenter()
                    ->toggleable(),

                Tables\Columns\IconColumn::make('is_pickup_enabled')
                    ->label(__('C&C'))
                    ->boolean()
                    ->alignCenter()
                    ->toggleable(),

                Tables\Columns\TextColumn::make('orders_count')
                    ->label(__('Orders'))
                    ->counts('orders')
                    ->sortable()
                    ->alignCenter()
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('updated_at')
                    ->label(__('Updated'))
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('city')
                    ->label(__('City'))
                    ->options(fn () => ZooboxiWarehouse::distinct()->pluck('city', 'city')->toArray()),

                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('Active')),

                Tables\Filters\TernaryFilter::make('is_central')
                    ->label(__('Central')),

                Tables\Filters\TernaryFilter::make('is_pickup_enabled')
                    ->label(__('Click & Collect')),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Section::make(__('Warehouse Info'))
                    ->schema([
                        Infolists\Components\TextEntry::make('warehouse_code')
                            ->label(__('Code'))
                            ->copyable(),
                        Infolists\Components\TextEntry::make('display_name_ar')
                            ->label(__('Name (AR)')),
                        Infolists\Components\TextEntry::make('display_name_en')
                            ->label(__('Name (EN)'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('city')
                            ->label(__('City'))
                            ->badge(),
                        Infolists\Components\TextEntry::make('address_ar')
                            ->label(__('Address (AR)'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('phone')
                            ->label(__('Phone'))
                            ->placeholder('-'),
                    ])->columns(3),

                Infolists\Components\Section::make(__('SAP Warehouse Codes'))
                    ->schema([
                        Infolists\Components\TextEntry::make('sap_warehouse_codes')
                            ->label(__('Mapped SAP Codes'))
                            ->badge()
                            ->separator(',')
                            ->columnSpanFull(),
                    ]),

                Infolists\Components\Section::make(__('Location & Delivery Settings'))
                    ->schema([
                        Infolists\Components\TextEntry::make('latitude')
                            ->label(__('Latitude')),
                        Infolists\Components\TextEntry::make('longitude')
                            ->label(__('Longitude')),
                        Infolists\Components\TextEntry::make('express_radius_km')
                            ->label(__('Express Radius'))
                            ->suffix(' km'),
                        Infolists\Components\IconEntry::make('is_active')
                            ->label(__('Active'))
                            ->boolean(),
                        Infolists\Components\IconEntry::make('is_central')
                            ->label(__('Central'))
                            ->boolean(),
                        Infolists\Components\IconEntry::make('is_main_hub')
                            ->label(__('Main Hub'))
                            ->boolean(),
                        Infolists\Components\IconEntry::make('is_pickup_enabled')
                            ->label(__('Click & Collect'))
                            ->boolean(),
                    ])->columns(4),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZooboxiWarehouses::route('/'),
            'edit' => Pages\EditZooboxiWarehouse::route('/{record}/edit'),
            'view' => Pages\ViewZooboxiWarehouse::route('/{record}'),
        ];
    }
}
