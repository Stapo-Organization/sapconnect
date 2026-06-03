<?php

namespace App\Filament\Resources;

use App\Filament\Resources\QualityTaskInstanceResource\Pages;
use App\Models\QualityTaskInstance;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class QualityTaskInstanceResource extends Resource
{
    protected static ?string $model = QualityTaskInstance::class;

    protected static ?string $navigationIcon = 'heroicon-o-clipboard-document-check';
    protected static ?int $navigationSort = 2;

    public static function getNavigationLabel(): string { return __('Quality Submissions'); }
    public static function getModelLabel(): string { return __('Quality Submission'); }
    public static function getPluralModelLabel(): string { return __('Quality Submissions'); }
    public static function getNavigationGroup(): ?string { return __('Quality Control'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Operations Manager']);
    }

    public static function canCreate(): bool { return false; }
    public static function canEdit($record): bool { return false; }
    public static function canDelete($record): bool { return false; }

    public static function form(Form $form): Form
    {
        return $form->schema([]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')->label('#')->sortable(),
                Tables\Columns\TextColumn::make('title')->label(__('Task'))->searchable()->sortable(),
                Tables\Columns\TextColumn::make('warehouse_code')->label(__('Warehouse'))->searchable()->sortable(),
                Tables\Columns\TextColumn::make('slot_key')
                    ->label(__('Slot'))
                    ->formatStateUsing(fn ($state) => $state === '_default' ? '—' : $state),
                Tables\Columns\TextColumn::make('scheduled_date')->label(__('Date'))->date()->sortable(),
                Tables\Columns\TextColumn::make('status')
                    ->label(__('Status'))
                    ->badge()
                    ->color(fn ($state) => match ($state) {
                        'submitted' => 'success', 'cancelled' => 'danger', default => 'gray',
                    })
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'submitted' => __('Submitted'), 'cancelled' => __('Cancelled'), default => __('Pending'),
                    }),
                Tables\Columns\TextColumn::make('photos_count')->counts('photos')->label(__('Photos')),
                Tables\Columns\TextColumn::make('submitter.name')->label(__('By'))->placeholder('—'),
                Tables\Columns\TextColumn::make('submitted_at')->label(__('Submitted At'))->dateTime('Y-m-d H:i')->sortable()->placeholder('—'),
            ])
            ->defaultSort('scheduled_date', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')->options([
                    'pending' => __('Pending'), 'submitted' => __('Submitted'), 'cancelled' => __('Cancelled'),
                ]),
                Tables\Filters\SelectFilter::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code')),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListQualityTaskInstances::route('/'),
            'view' => Pages\ViewQualityTaskInstance::route('/{record}'),
        ];
    }
}
