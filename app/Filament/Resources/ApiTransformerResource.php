<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ApiTransformerResource\Pages;
use App\Models\ApiTransformer;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class ApiTransformerResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    protected static ?string $model = ApiTransformer::class;

    protected static ?string $navigationIcon = 'heroicon-o-adjustments-horizontal';

    public static function getNavigationLabel(): string
    {
        return __('API Custom Views');
    }

    public static function getModelLabel(): string
    {
        return __('API Custom View');
    }

    public static function getPluralModelLabel(): string
    {
        return __('API Custom Views');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('System');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Configuration'))
                    ->schema([
                        Forms\Components\TextInput::make('resource')
                            ->required()
                            ->label(__('SAP Resource'))
                            ->placeholder(__('e.g. Items'))
                            ->helperText(__('The SAP entity name.'))
                            ->live(onBlur: true), // Live update to trigger schema fetch
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->label(__('View Name'))
                            ->placeholder(__('e.g. Mobile'))
                            ->helperText(__('The ?view= parameter value.')),
                        Forms\Components\Toggle::make('is_active')
                            ->default(true)
                            ->label(__('Active')),
                    ])->columns(2),

                Forms\Components\Section::make(__('Transformation Rules'))
                    ->schema([
                        Forms\Components\Repeater::make('mapping')
                            ->schema([
                                Forms\Components\Grid::make(3)
                                    ->schema([
                                        Forms\Components\TextInput::make('source')
                                            ->required()
                                            ->label(__('Source Field (SAP)'))
                                            ->placeholder(__('Select or Type...'))
                                            ->datalist(function (Forms\Get $get) {
                                                $resource = $get('../../resource');
                                                if (!$resource)
                                                    return [];

                                                return cache()->remember("sap_schema_{$resource}", 60, function () use ($resource) {
                                                    try {
                                                        $sap = app(\App\Services\SAP\SapClient::class);
                                                        // Fetch 1 item to get schema
                                                        $data = $sap->get($resource, ['$top' => 1]);
                                                        $item = $data['value'][0] ?? null;
                                                        if (!$item)
                                                            return [];
                                                        $keys = array_keys($item);
                                                        return $keys;
                                                    } catch (\Exception $e) {
                                                        return [];
                                                    }
                                                });
                                            })
                                            ->live()
                                            ->afterStateUpdated(function (Forms\Set $set, Forms\Get $get, $state) {
                                                // Auto-detect type
                                                $resource = $get('../../resource');
                                                if (!$resource || !$state)
                                                    return;

                                                try {
                                                    $sap = app(\App\Services\SAP\SapClient::class);
                                                    // We rely on cache hopefully populated above
                                                    $data = $sap->get($resource, ['$top' => 1]);
                                                    $item = $data['value'][0] ?? [];
                                                    $val = $item[$state] ?? null;

                                                    if (is_array($val))
                                                        $set('type', 'array');
                                                    elseif (is_bool($val))
                                                        $set('type', 'boolean');
                                                    elseif (is_int($val))
                                                        $set('type', 'integer');
                                                    elseif (is_float($val))
                                                        $set('type', 'float');
                                                    else
                                                        $set('type', 'string');

                                                    // Auto-set target to same name if empty
                                                    if (!$get('target'))
                                                        $set('target', $state);
                                                } catch (\Exception $e) {
                                                }
                                            }),

                                        Forms\Components\TextInput::make('target')
                                            ->required()
                                            ->label(__('Target Field (API)'))
                                            ->placeholder(__('e.g. id')),
                                        Forms\Components\Select::make('type')
                                            ->label(__('Data Type'))
                                            ->options([
                                                'string' => __('String'),
                                                'integer' => __('Integer'),
                                                'float' => __('Float'),
                                                'boolean' => __('Boolean'),
                                                'array' => __('List / Array'),
                                            ])
                                            ->default('string')
                                            ->required()
                                            ->reactive(),
                                    ]),

                                // Nested Mapping for Arrays
                                Forms\Components\Repeater::make('sub_mapping')
                                    ->label(__('Nested Fields (for List/Array)'))
                                    ->schema([
                                        Forms\Components\TextInput::make('source')
                                            ->label(__('Source Key'))
                                            ->required()
                                            ->datalist(function (Forms\Get $get) {
                                                $resource = $get('../../../resource');
                                                $parentSource = $get('../source');
                                                if (!$resource || !$parentSource)
                                                    return [];

                                                return cache()->remember("sap_schema_{$resource}_{$parentSource}", 60, function () use ($resource, $parentSource) {
                                                    try {
                                                        $sap = app(\App\Services\SAP\SapClient::class);
                                                        $data = $sap->get($resource, ['$top' => 1]);
                                                        $item = $data['value'][0] ?? [];
                                                        $subItem = $item[$parentSource][0] ?? null; // Assume array of objects
                                                        if (!$subItem || !is_array($subItem))
                                                            return [];
                                                        $keys = array_keys($subItem);
                                                        return $keys;
                                                    } catch (\Exception $e) {
                                                        return [];
                                                    }
                                                });
                                            })
                                            ->live()
                                            ->afterStateUpdated(function (Forms\Set $set, Forms\Get $get, $state) {
                                                // Auto-detect type nested
                                                $resource = $get('../../../resource');
                                                $parentSource = $get('../source');
                                                if (!$resource || !$parentSource || !$state)
                                                    return;

                                                try {
                                                    $sap = app(\App\Services\SAP\SapClient::class);
                                                    $data = $sap->get($resource, ['$top' => 1]);
                                                    $item = $data['value'][0] ?? [];
                                                    $subItem = $item[$parentSource][0] ?? [];
                                                    $val = $subItem[$state] ?? null;

                                                    if (is_int($val))
                                                        $set('type', 'integer');
                                                    elseif (is_float($val))
                                                        $set('type', 'float');
                                                    else
                                                        $set('type', 'string');

                                                    if (!$get('target'))
                                                        $set('target', $state);
                                                } catch (\Exception $e) {
                                                }
                                            }),
                                        Forms\Components\TextInput::make('target')
                                            ->label(__('Target Key'))
                                            ->required(),
                                        Forms\Components\Select::make('type')
                                            ->label(__('Data Type'))
                                            ->options([
                                                'string' => __('String'),
                                                'integer' => __('Integer'),
                                                'float' => __('Float'),
                                            ])
                                            ->default('string')
                                            ->required(),
                                    ])
                                    ->columns(3)
                                    ->visible(fn(Forms\Get $get) => $get('type') === 'array')
                                    ->defaultItems(1),
                            ])
                            ->columns(1)
                            ->defaultItems(1)
                            ->label(__('Field Mappings')),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('resource')->sortable()->searchable()->label(__('SAP Resource')),
                Tables\Columns\TextColumn::make('name')->sortable()->searchable()->label(__('View Name')),
                Tables\Columns\IconColumn::make('is_active')->boolean()->label(__('Active')),
                Tables\Columns\TextColumn::make('created_at')->dateTime()->label(__('Created At')),
            ])
            ->filters([
                //
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListApiTransformers::route('/'),
            'create' => Pages\CreateApiTransformer::route('/create'),
            'edit' => Pages\EditApiTransformer::route('/{record}/edit'),
        ];
    }
}
