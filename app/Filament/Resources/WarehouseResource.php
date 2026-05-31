<?php

namespace App\Filament\Resources;

use App\Filament\Resources\WarehouseResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Warehouse;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class WarehouseResource extends Resource
{
    use ReadOnlyStakeholder;

    public static function canViewAny(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected static ?string $model = Warehouse::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-office-2';

    public static function getNavigationLabel(): string
    {
        return __('Warehouses');
    }

    public static function getModelLabel(): string
    {
        return __('Warehouse');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Warehouses');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Master Data');
    }

    protected static ?int $navigationSort = 3;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('warehouse_code')
                    ->label(__('Warehouse Code'))
                    ->required()
                    ->maxLength(255),
                Forms\Components\TextInput::make('warehouse_name')
                    ->label(__('Warehouse Name'))
                    ->maxLength(255),
                Forms\Components\Select::make('source')
                    ->label(__('Source'))
                    ->options([
                        'production' => __('Production'),
                    ])
                    ->required(),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(function (Builder $query) {
                return $query->where('source', 'production');
            })
            ->columns([
                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label(__('Warehouse Code'))
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('warehouse_name')
                    ->label(__('Warehouse Name'))
                    ->searchable()
                    ->sortable(),
                Tables\Columns\BadgeColumn::make('source')
                    ->label(__('Source'))
                    ->colors([
                        'success' => 'production',
                    ]),
                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('Created At'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('updated_at')
                    ->label(__('Updated At'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('source')
                    ->label(__('Source'))
                    ->options([
                        'production' => __('Production'),
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

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListWarehouses::route('/'),
            'create' => Pages\CreateWarehouse::route('/create'),
            'edit' => Pages\EditWarehouse::route('/{record}/edit'),
        ];
    }
}
