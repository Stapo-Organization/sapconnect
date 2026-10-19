<?php

namespace App\Filament\Resources;

use App\Models\ProductBarcode;
use App\Models\WarehouseItemStock;
use App\Services\SAP\ItemBarcodeResolver;
use Illuminate\Database\Eloquent\Builder;
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
                    ->searchable(query: fn (Builder $query, string $search) => self::searchProduct($query, $search))
                    ->sortable()
                    ->description(fn (WarehouseItemStock $record): string => collect([$record->product?->item_name ?? 'بدون وصف', $record->product?->piece_barcode])->filter()->join(' · ')),
                
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
            ->modifyQueryUsing(fn (Builder $query) => $query->with('product:id,item_code,item_name,piece_barcode'))
            ->searchPlaceholder('الكود أو الاسم أو الباركود')
            ->defaultSort('in_stock', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('warehouse_code')
                    ->label('الفلترة بالمستودع')
                    ->options(fn () => \App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code')->toArray()),
            ]);
    }

    /**
     * Item code, product name, piece barcode, or any other barcode the item
     * answers to (carton, legacy, leading zero dropped by the scanner).
     */
    public static function searchProduct(Builder $query, string $search): Builder
    {
        $term = trim($search);
        $norm = ItemBarcodeResolver::normalize($term);

        return $query->where(function (Builder $q) use ($term, $norm) {
            $q->where('item_code', 'like', "%{$term}%")
                ->orWhereHas('product', fn (Builder $p) => $p->where('piece_barcode', 'like', "%{$term}%")
                    ->orWhere('item_name', 'like', "%{$term}%")
                    ->orWhere('zb_name_ar', 'like', "%{$term}%"));
            if (strlen($norm) >= 6) {
                $q->orWhereIn('item_code', ProductBarcode::where('barcode_norm', $norm)->select('item_code'));
            }
        });
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListWarehouseItemStocks::route('/'),
        ];
    }
}
