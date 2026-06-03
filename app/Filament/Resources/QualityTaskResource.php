<?php

namespace App\Filament\Resources;

use App\Filament\Resources\QualityTaskResource\Pages;
use App\Models\QualityTask;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class QualityTaskResource extends Resource
{
    protected static ?string $model = QualityTask::class;

    protected static ?string $navigationIcon = 'heroicon-o-shield-check';
    protected static ?int $navigationSort = 1;

    public static function getNavigationLabel(): string { return __('Quality Tasks'); }
    public static function getModelLabel(): string { return __('Quality Task'); }
    public static function getPluralModelLabel(): string { return __('Quality Tasks'); }
    public static function getNavigationGroup(): ?string { return __('Quality Control'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Operations Manager']);
    }

    /**
     * Assign stable keys to checklist items / slots (used by Create & Edit).
     */
    public static function normalizeData(array $data): array
    {
        if (!empty($data['checklist_items']) && is_array($data['checklist_items'])) {
            $i = 0;
            $data['checklist_items'] = array_map(function ($item) use (&$i) {
                $i++;
                return [
                    'key' => $item['key'] ?? ('item_' . $i),
                    'label' => $item['label'] ?? '',
                    'require_photo' => (bool) ($item['require_photo'] ?? true),
                ];
            }, array_values($data['checklist_items']));
        }

        if (!empty($data['slots']) && is_array($data['slots'])) {
            $i = 0;
            $data['slots'] = array_map(function ($slot) use (&$i) {
                $i++;
                return [
                    'key' => $slot['key'] ?: ('slot_' . $i),
                    'label_ar' => $slot['label_ar'] ?? '',
                    'label_en' => $slot['label_en'] ?? '',
                ];
            }, array_values($data['slots']));
        }

        return $data;
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make(__('Task'))
                ->columns(2)
                ->schema([
                    Forms\Components\TextInput::make('title')
                        ->label(__('Title'))
                        ->required()
                        ->maxLength(255)
                        ->placeholder('نظافة المدخل'),

                    Forms\Components\Select::make('priority')
                        ->label(__('Priority'))
                        ->options(['high' => __('High'), 'medium' => __('Medium'), 'low' => __('Low')])
                        ->default('medium')
                        ->required(),

                    Forms\Components\Textarea::make('description')
                        ->label(__('Description'))
                        ->rows(2)
                        ->columnSpanFull(),

                    // Create: one or more warehouses → a task per warehouse.
                    Forms\Components\Select::make('warehouse_codes')
                        ->label(__('Warehouses'))
                        ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code'))
                        ->multiple()
                        ->searchable()
                        ->required()
                        ->helperText(__('Select one or more branches — a separate task is created for each'))
                        ->visible(fn (string $operation) => $operation === 'create')
                        ->columnSpanFull(),

                    Forms\Components\Select::make('warehouse_code')
                        ->label(__('Warehouse'))
                        ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code'))
                        ->searchable()
                        ->required()
                        ->visible(fn (string $operation) => $operation === 'edit')
                        ->columnSpanFull(),
                ]),

            Forms\Components\Section::make(__('Proof Requirement'))
                ->columns(2)
                ->schema([
                    Forms\Components\Select::make('proof_type')
                        ->label(__('Proof Type'))
                        ->options([
                            'acknowledge' => __('Acknowledge only'),
                            'photo' => __('Photo(s) + optional comment'),
                            'checklist' => __('Checklist (per-item photo)'),
                        ])
                        ->default('photo')
                        ->required()
                        ->live(),

                    Forms\Components\TextInput::make('min_photos')
                        ->label(__('Minimum photos'))
                        ->numeric()
                        ->default(1)
                        ->minValue(1)
                        ->maxValue(30)
                        ->visible(fn (Get $get) => $get('proof_type') === 'photo'),

                    Forms\Components\Toggle::make('require_comment')
                        ->label(__('Require a comment'))
                        ->default(false)
                        ->visible(fn (Get $get) => $get('proof_type') === 'photo'),

                    Forms\Components\Repeater::make('checklist_items')
                        ->label(__('Checklist items'))
                        ->schema([
                            Forms\Components\TextInput::make('label')
                                ->label(__('Item'))
                                ->required()
                                ->placeholder('ممر 1'),
                            Forms\Components\Toggle::make('require_photo')
                                ->label(__('Requires photo'))
                                ->default(true),
                        ])
                        ->columns(2)
                        ->reorderable()
                        ->collapsible()
                        ->defaultItems(1)
                        ->itemLabel(fn (array $state) => $state['label'] ?? __('Item'))
                        ->visible(fn (Get $get) => $get('proof_type') === 'checklist')
                        ->columnSpanFull(),
                ]),

            Forms\Components\Section::make(__('Schedule'))
                ->columns(2)
                ->schema([
                    Forms\Components\Select::make('recurrence')
                        ->label(__('Recurrence'))
                        ->options([
                            'once' => __('Once'),
                            'daily' => __('Daily'),
                            'weekly' => __('Weekly'),
                        ])
                        ->default('daily')
                        ->required()
                        ->live(),

                    Forms\Components\CheckboxList::make('days_of_week')
                        ->label(__('Days of week'))
                        ->options([
                            0 => __('Sunday'), 1 => __('Monday'), 2 => __('Tuesday'),
                            3 => __('Wednesday'), 4 => __('Thursday'), 5 => __('Friday'), 6 => __('Saturday'),
                        ])
                        ->columns(2)
                        ->visible(fn (Get $get) => $get('recurrence') === 'weekly'),

                    Forms\Components\Repeater::make('slots')
                        ->label(__('Time slots (optional)'))
                        ->helperText(__('Add slots for tasks done more than once a day (e.g. Morning + Evening). Leave empty for once a day.'))
                        ->schema([
                            Forms\Components\TextInput::make('label_ar')->label(__('Label (Arabic)'))->placeholder('صباحاً')->required(),
                            Forms\Components\TextInput::make('label_en')->label(__('Label (English)'))->placeholder('Morning'),
                            Forms\Components\Hidden::make('key'),
                        ])
                        ->columns(2)
                        ->collapsible()
                        ->itemLabel(fn (array $state) => $state['label_ar'] ?? __('Slot'))
                        ->columnSpanFull(),

                    Forms\Components\DatePicker::make('start_date')->label(__('Start date')),
                    Forms\Components\DatePicker::make('end_date')->label(__('End date')),

                    Forms\Components\Toggle::make('is_active')
                        ->label(__('Active'))
                        ->default(true)
                        ->helperText(__('Only active tasks generate daily instances')),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('title')->label(__('Title'))->searchable()->sortable(),
                Tables\Columns\TextColumn::make('warehouse_code')->label(__('Warehouse'))->searchable()->sortable(),
                Tables\Columns\TextColumn::make('proof_type')
                    ->label(__('Proof'))
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        'acknowledge' => 'gray', 'photo' => 'info', 'checklist' => 'warning', default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('recurrence')->label(__('Recurrence'))->badge()->color('primary'),
                Tables\Columns\TextColumn::make('today_progress')
                    ->label(__("Today"))
                    ->badge()
                    ->color('success')
                    ->getStateUsing(function ($record) {
                        $stats = $record->instances()
                            ->whereDate('scheduled_date', today())
                            ->selectRaw("SUM(status = 'submitted') as submitted, COUNT(*) as total")
                            ->first();
                        return ($stats->submitted ?? 0) . '/' . ($stats->total ?? 0);
                    }),
                Tables\Columns\IconColumn::make('is_active')->label(__('Active'))->boolean()->sortable(),
                Tables\Columns\TextColumn::make('last_generated_at')->label(__('Last Generated'))->dateTime('Y-m-d H:i')->sortable()->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')->label(__('Status'))->trueLabel(__('Active'))->falseLabel(__('Inactive')),
                Tables\Filters\SelectFilter::make('proof_type')->options(['acknowledge' => __('Acknowledge'), 'photo' => __('Photo'), 'checklist' => __('Checklist')]),
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
                        $count = (new \App\Services\Quality\QualityTaskGenerationService())->generateForTask($record, now());
                        \Filament\Notifications\Notification::make()
                            ->title($count > 0 ? __('Instances generated') : __('Nothing due today'))
                            ->body($count > 0 ? __(':count instance(s) created.', ['count' => $count]) : null)
                            ->{$count > 0 ? 'success' : 'warning'}()
                            ->send();
                    }),
                Tables\Actions\DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListQualityTasks::route('/'),
            'create' => Pages\CreateQualityTask::route('/create'),
            'edit' => Pages\EditQualityTask::route('/{record}/edit'),
        ];
    }
}
