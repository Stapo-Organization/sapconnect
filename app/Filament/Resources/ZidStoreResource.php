<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZidStoreResource\Pages;
use App\Models\ZidStore;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class ZidStoreResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected static ?string $model = ZidStore::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';
    
    public static function getNavigationLabel(): string
    {
        return __('Zid Stores');
    }

    public static function getModelLabel(): string
    {
        return __('Zid Store');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Zid Stores');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Zid OMS');
    }

    protected static ?int $navigationSort = 1;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('name')
                    ->label(__('Name'))
                    ->required()
                    ->maxLength(255),
                Forms\Components\TextInput::make('store_id')
                    ->label(__('Store ID'))
                    ->required()
                    ->maxLength(255),
                Forms\Components\Textarea::make('x_manager_token')
                    ->label(__('X-Manager-Token'))
                    ->rows(3)
                    ->columnSpanFull(),
                Forms\Components\Textarea::make('authorization_token')
                    ->label(__('Authorization Token'))
                    ->rows(3)
                    ->columnSpanFull(),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label(__('Name'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('store_id')
                    ->label(__('Store ID'))
                    ->searchable(),
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

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZidStores::route('/'),
            'create' => Pages\CreateZidStore::route('/create'),
            'edit' => Pages\EditZidStore::route('/{record}/edit'),
        ];
    }
}
