<?php

namespace App\Filament\Resources;

use App\Filament\Resources\InventoryCyclePlanResource\Pages;
use App\Models\InventoryCyclePlan;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class InventoryCyclePlanResource extends Resource
{
    protected static ?string $model = InventoryCyclePlan::class;

    protected static ?string $navigationIcon = 'heroicon-o-calendar-days';
    protected static ?int $navigationSort = 5;

    public static function getNavigationLabel(): string { return __('Cycle Plans'); }
    public static function getModelLabel(): string { return __('Cycle Plan'); }
    public static function getPluralModelLabel(): string { return __('Cycle Plans'); }
    public static function getNavigationGroup(): ?string { return __('Retail'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin']);
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make(__('Cycle Plan Configuration'))
                ->columns(2)
                ->schema([
                    Forms\Components\TextInput::make('plan_name')
                        ->label(__('Plan Name'))
                        ->required()
                        ->maxLength(255)
                        ->placeholder('خطة الجرد الدوري — فرع الرياض'),

                    // On create: choose one or more warehouses — a plan is created for each.
                    Forms\Components\Select::make('warehouse_codes')
                        ->label(__('Warehouses'))
                        ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code'))
                        ->multiple()
                        ->searchable()
                        ->required()
                        ->helperText(__('Select one or more warehouses — a separate plan is created for each'))
                        ->visible(fn (string $operation) => $operation === 'create'),

                    // On edit: a plan belongs to a single warehouse.
                    Forms\Components\Select::make('warehouse_code')
                        ->label(__('Warehouse'))
                        ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code'))
                        ->searchable()
                        ->required()
                        ->visible(fn (string $operation) => $operation === 'edit'),

                    Forms\Components\TextInput::make('weekly_cap')
                        ->label(__('Weekly Cap (items)'))
                        ->numeric()
                        ->default(120)
                        ->minValue(10)
                        ->maxValue(500)
                        ->required()
                        ->helperText(__('Maximum items per weekly counting session')),

                    Forms\Components\TextInput::make('cycle_length_weeks')
                        ->label(__('Cycle Length (weeks)'))
                        ->numeric()
                        ->default(13)
                        ->minValue(4)
                        ->maxValue(52)
                        ->required()
                        ->helperText(__('Full cycle duration in weeks (13 = quarterly)')),
                ]),

            Forms\Components\Section::make(__('ABC Frequency'))
                ->columns(3)
                ->description(__('How many times each class should be counted per cycle'))
                ->schema([
                    Forms\Components\TextInput::make('a_frequency')
                        ->label(__('A Class Frequency'))
                        ->numeric()
                        ->default(4)
                        ->minValue(1)
                        ->maxValue(13)
                        ->required()
                        ->helperText(__('High-value items')),

                    Forms\Components\TextInput::make('b_frequency')
                        ->label(__('B Class Frequency'))
                        ->numeric()
                        ->default(2)
                        ->minValue(1)
                        ->maxValue(13)
                        ->required()
                        ->helperText(__('Medium-value items')),

                    Forms\Components\TextInput::make('c_frequency')
                        ->label(__('C Class Frequency'))
                        ->numeric()
                        ->default(1)
                        ->minValue(1)
                        ->maxValue(13)
                        ->required()
                        ->helperText(__('Low-value items')),
                ]),

            Forms\Components\Section::make(__('Tolerance Settings'))
                ->columns(3)
                ->description(__('Maximum acceptable variance percentage per class'))
                ->schema([
                    Forms\Components\TextInput::make('tolerance_a')
                        ->label(__('A Class Tolerance %'))
                        ->numeric()
                        ->default(2)
                        ->minValue(0)
                        ->maxValue(20)
                        ->suffix('%'),

                    Forms\Components\TextInput::make('tolerance_b')
                        ->label(__('B Class Tolerance %'))
                        ->numeric()
                        ->default(5)
                        ->minValue(0)
                        ->maxValue(30)
                        ->suffix('%'),

                    Forms\Components\TextInput::make('tolerance_c')
                        ->label(__('C Class Tolerance %'))
                        ->numeric()
                        ->default(10)
                        ->minValue(0)
                        ->maxValue(50)
                        ->suffix('%'),
                ]),

            Forms\Components\Section::make(__('Status'))
                ->columns(2)
                ->schema([
                    Forms\Components\Toggle::make('is_active')
                        ->label(__('Active'))
                        ->default(true)
                        ->helperText(__('Only active plans generate weekly lists')),

                    Forms\Components\DatePicker::make('next_due_date')
                        ->label(__('Next Due Date'))
                        ->helperText(__('When the next weekly list should be generated')),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('plan_name')
                    ->label(__('Plan Name'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('weekly_cap')
                    ->label(__('Weekly Cap'))
                    ->sortable(),

                Tables\Columns\TextColumn::make('cycle_length_weeks')
                    ->label(__('Cycle (weeks)'))
                    ->sortable(),

                Tables\Columns\TextColumn::make('current_week_number')
                    ->label(__('Current Week'))
                    ->formatStateUsing(fn ($record) => "{$record->current_week_number}/{$record->cycle_length_weeks}")
                    ->sortable(),

                Tables\Columns\TextColumn::make('a_frequency')
                    ->label('A')
                    ->alignCenter()
                    ->badge()
                    ->color('danger'),

                Tables\Columns\TextColumn::make('b_frequency')
                    ->label('B')
                    ->alignCenter()
                    ->badge()
                    ->color('warning'),

                Tables\Columns\TextColumn::make('c_frequency')
                    ->label('C')
                    ->alignCenter()
                    ->badge()
                    ->color('gray'),

                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('Active'))
                    ->boolean()
                    ->sortable(),

                Tables\Columns\TextColumn::make('next_due_date')
                    ->label(__('Next Due'))
                    ->date()
                    ->sortable(),

                Tables\Columns\TextColumn::make('last_generated_at')
                    ->label(__('Last Generated'))
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('Status'))
                    ->trueLabel(__('Active'))
                    ->falseLabel(__('Inactive')),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\Action::make('generate_now')
                    ->label(__('Generate Now'))
                    ->icon('heroicon-o-play')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn ($record) => $record->is_active)
                    ->action(function ($record) {
                        $service = new \App\Services\Counting\WeeklyCountingListService();
                        $result = $service->generateForPlan($record);
                        if ($result) {
                            \Filament\Notifications\Notification::make()
                                ->title(__('Weekly list generated'))
                                ->body("Session #{$result->id} — {$result->total_target_items} items")
                                ->success()
                                ->send();
                        } else {
                            \Filament\Notifications\Notification::make()
                                ->title(__('No items to count'))
                                ->warning()
                                ->send();
                        }
                    }),
                Tables\Actions\Action::make('reclassify')
                    ->label(__('Re-classify ABC'))
                    ->icon('heroicon-o-arrow-path')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->action(function ($record) {
                        $service = new \App\Services\Counting\AbcClassificationService();
                        $result = $service->classifyWarehouse($record->warehouse_code);
                        \Filament\Notifications\Notification::make()
                            ->title(__('ABC Classification Complete'))
                            ->body("A: {$result['A']} | B: {$result['B']} | C: {$result['C']} | Total: {$result['total']}")
                            ->success()
                            ->send();
                    }),
                Tables\Actions\DeleteAction::make(),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListInventoryCyclePlans::route('/'),
            'create' => Pages\CreateInventoryCyclePlan::route('/create'),
            'edit' => Pages\EditInventoryCyclePlan::route('/{record}/edit'),
        ];
    }
}
