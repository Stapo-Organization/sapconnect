<?php

namespace App\Filament\Resources;

use App\Filament\Resources\InventoryCountingResource\Pages;
use App\Models\InventoryCounting;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class InventoryCountingResource extends Resource
{
    protected static ?string $model = InventoryCounting::class;

    protected static ?string $navigationIcon = 'heroicon-o-clipboard-document-check';
    protected static ?int $navigationSort = 4;

    public static function getNavigationLabel(): string { return __('Inventory Counting'); }
    public static function getModelLabel(): string { return __('Inventory Counting'); }
    public static function getPluralModelLabel(): string { return __('Inventory Countings'); }
    public static function getNavigationGroup(): ?string { return __('Retail'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager', 'Stakeholder']);
    }

    public static function canCreate(): bool
    {
        // Stakeholder can only view, not create
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager']);
    }

    public static function canEdit($record): bool
    {
        // Only editable while draft and by Super Admin or Branch Manager
        if (!auth()->check()) return false;
        if (!auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager'])) return false;
        return $record->isDraft();
    }

    public static function canDelete($record): bool
    {
        if (!auth()->check()) return false;
        if (!auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager'])) return false;
        return $record->isDraft();
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();

        $user = auth()->user();
        // Filter by warehouse for Branch Managers
        if ($user && $user->warehouse_code && !$user->hasRole('Super Admin')) {
            $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
            if (!empty($codes)) {
                $query->whereIn('warehouse_code', $codes);
            }
        }

        return $query;
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make(__('Inventory Counting'))
                ->columns(2)
                ->schema([
                    Forms\Components\Select::make('warehouse_code')
                        ->label(__('Select Warehouse'))
                        ->options(function () {
                            $user = auth()->user();
                            $query = \App\Models\Warehouse::query()->production();

                            if ($user && $user->warehouse_code && !$user->hasRole('Super Admin')) {
                                $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                                $query->whereIn('warehouse_code', $codes);
                            }

                            return $query->pluck('warehouse_name', 'warehouse_code');
                        })
                        ->searchable()
                        ->required()
                        ->reactive()
                        ->afterStateUpdated(function ($state, Forms\Set $set) {
                            $warehouse = \App\Models\Warehouse::where('warehouse_code', $state)->first();
                            if ($warehouse) {
                                $set('warehouse_name', $warehouse->warehouse_name);
                            }
                        }),

                    Forms\Components\Hidden::make('warehouse_name'),

                    Forms\Components\Select::make('status')
                        ->label(__('Status'))
                        ->options([
                            'draft' => __('Draft'),
                            'completed' => __('Completed'),
                        ])
                        ->default('draft')
                        ->disabled(),

                    Forms\Components\Textarea::make('notes')
                        ->label(__('Notes'))
                        ->columnSpanFull(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('#')
                    ->sortable(),

                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label(__('Warehouse Code'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('warehouse_name')
                    ->label(__('Warehouse Name'))
                    ->searchable(),

                Tables\Columns\BadgeColumn::make('status')
                    ->label(__('Status'))
                    ->colors([
                        'warning' => 'draft',
                        'success' => 'completed',
                    ])
                    ->formatStateUsing(fn (string $state) => $state === 'draft' ? __('Draft') : __('Completed')),

                Tables\Columns\TextColumn::make('lines_count')
                    ->counts('lines')
                    ->label(__('Items Count'))
                    ->sortable(),

                Tables\Columns\TextColumn::make('user.name')
                    ->label(__('Counted By'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('Created At'))
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),

                Tables\Columns\TextColumn::make('completed_at')
                    ->label(__('Completed At'))
                    ->dateTime('Y-m-d H:i')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label(__('Status'))
                    ->options([
                        'draft' => __('Draft'),
                        'completed' => __('Completed'),
                    ]),
                Tables\Filters\SelectFilter::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code')),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make()
                    ->visible(fn ($record) => $record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager'])),
                Tables\Actions\Action::make('complete')
                    ->label(__('Mark as Completed'))
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn ($record) => $record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager']))
                    ->action(function ($record) {
                        $record->markAsCompleted();
                        \Filament\Notifications\Notification::make()
                            ->title(__('Inventory count completed'))
                            ->success()
                            ->send();
                    }),
                Tables\Actions\DeleteAction::make()
                    ->visible(fn ($record) => $record->isDraft() && auth()->user()->hasAnyRole(['Super Admin', 'Branch Manager'])),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListInventoryCountings::route('/'),
            'create' => Pages\CreateInventoryCounting::route('/create'),
            'view' => Pages\ViewInventoryCounting::route('/{record}'),
            'edit' => Pages\EditInventoryCounting::route('/{record}/edit'),
        ];
    }
}
