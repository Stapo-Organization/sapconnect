<?php

namespace App\Filament\Resources;

use App\Models\WarehouseItemStock;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use App\Filament\Resources\WarehouseItemStockResource\Pages;

class WarehouseItemStockResource extends Resource
{
    protected static ?string $model = WarehouseItemStock::class;

    protected static ?string $navigationIcon = 'heroicon-o-cube';
    protected static ?int $navigationSort = 3;

    public static function getNavigationLabel(): string { return __('Product Inventory'); }
    public static function getModelLabel(): string { return __('Inventory'); }
    public static function getPluralModelLabel(): string { return __('Product Inventory'); }
    public static function getNavigationGroup(): ?string { return __('Retail'); }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('item_code')
                    ->label('المنتج')
                    ->searchable()
                    ->sortable()
                    ->description(fn (WarehouseItemStock $record): string => $record->product?->item_name ?? 'بدون وصف'),
                
                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label('المستودع')
                    ->searchable()
                    ->sortable()
                    ->badge()
                    ->color('primary'),
                    
                Tables\Columns\TextColumn::make('in_stock')
                    ->label('الكمية الحالية')
                    ->numeric()
                    ->sortable()
                    ->badge()
                    ->color(fn (string $state): string => $state > 0 ? 'success' : 'danger'),
            ])
            ->defaultSort('in_stock', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('warehouse_code')
                    ->label('الفلترة بالمستودع')
                    ->options(fn () => \App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code')->toArray()),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListWarehouseItemStocks::route('/'),
        ];
    }
}
