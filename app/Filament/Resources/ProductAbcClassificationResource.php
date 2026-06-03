<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ProductAbcClassificationResource\Pages;
use App\Models\ProductAbcClassification;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ProductAbcClassificationResource extends Resource
{
    protected static ?string $model = ProductAbcClassification::class;

    protected static ?string $navigationIcon = 'heroicon-o-chart-pie';
    protected static ?int $navigationSort = 6;

    public static function getNavigationLabel(): string { return __('ABC Classification'); }
    public static function getModelLabel(): string { return __('ABC Classification'); }
    public static function getPluralModelLabel(): string { return __('ABC Classifications'); }
    public static function getNavigationGroup(): ?string { return __('Retail'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Stakeholder']);
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
                Tables\Columns\TextColumn::make('item_code')
                    ->label(__('Item Code'))
                    ->searchable()
                    ->sortable()
                    ->copyable(),

                Tables\Columns\TextColumn::make('product.item_name')
                    ->label(__('Item Name'))
                    ->searchable()
                    ->limit(35),

                Tables\Columns\TextColumn::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->searchable()
                    ->sortable(),

                Tables\Columns\BadgeColumn::make('abc_class')
                    ->label(__('ABC Class'))
                    ->colors([
                        'danger' => 'A',
                        'warning' => 'B',
                        'gray' => 'C',
                    ])
                    ->sortable(),

                Tables\Columns\TextColumn::make('annual_sales_value')
                    ->label(__('Annual Sales Value'))
                    ->money('SAR')
                    ->sortable(),

                Tables\Columns\TextColumn::make('annual_sales_qty')
                    ->label(__('Annual Sales Qty'))
                    ->numeric()
                    ->sortable(),

                Tables\Columns\TextColumn::make('current_stock')
                    ->label(__('Current Stock'))
                    ->numeric()
                    ->sortable(),

                Tables\Columns\TextColumn::make('count_in_cycle')
                    ->label(__('Times Counted'))
                    ->numeric()
                    ->sortable()
                    ->alignCenter(),

                Tables\Columns\TextColumn::make('last_counted_at')
                    ->label(__('Last Counted'))
                    ->dateTime('Y-m-d')
                    ->sortable()
                    ->placeholder(__('Never')),

                Tables\Columns\TextColumn::make('last_variance_pct')
                    ->label(__('Last Variance %'))
                    ->numeric(decimalPlaces: 1)
                    ->suffix('%')
                    ->sortable()
                    ->color(fn ($state) => match (true) {
                        $state === null => 'gray',
                        abs($state) <= 2 => 'success',
                        abs($state) <= 10 => 'warning',
                        default => 'danger',
                    }),

                Tables\Columns\TextColumn::make('last_calculated_at')
                    ->label(__('Classified At'))
                    ->dateTime('Y-m-d')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('annual_sales_value', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('abc_class')
                    ->label(__('ABC Class'))
                    ->options([
                        'A' => 'A — ' . __('High Value'),
                        'B' => 'B — ' . __('Medium Value'),
                        'C' => 'C — ' . __('Low Value'),
                    ]),
                Tables\Filters\SelectFilter::make('warehouse_code')
                    ->label(__('Warehouse'))
                    ->options(fn () => \App\Models\Warehouse::production()->pluck('warehouse_name', 'warehouse_code')),
                Tables\Filters\TernaryFilter::make('never_counted')
                    ->label(__('Counting Status'))
                    ->trueLabel(__('Never Counted'))
                    ->falseLabel(__('Counted'))
                    ->queries(
                        true: fn (Builder $query) => $query->whereNull('last_counted_at'),
                        false: fn (Builder $query) => $query->whereNotNull('last_counted_at'),
                    ),
            ])
            ->actions([])
            ->headerActions([
                Tables\Actions\Action::make('reclassify_all')
                    ->label(__('Re-classify All Warehouses'))
                    ->icon('heroicon-o-arrow-path')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->visible(fn () => auth()->user()->hasRole('Super Admin'))
                    ->action(function () {
                        $service = new \App\Services\Counting\AbcClassificationService();
                        $warehouses = [
                            'RUH002', 'RUH004', 'RUH005', 'RUH006', 'RUH007', 'RUH008',
                            'JED002', 'DMM001', 'MED001', 'ABH001', 'UZH001', 'KHO001', 'HBT001',
                        ];
                        $total = 0;
                        foreach ($warehouses as $code) {
                            $result = $service->classifyWarehouse($code);
                            $total += $result['total'];
                        }
                        \Filament\Notifications\Notification::make()
                            ->title(__('ABC Classification Complete'))
                            ->body("Classified {$total} items across " . count($warehouses) . " warehouses")
                            ->success()
                            ->send();
                    }),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListProductAbcClassifications::route('/'),
        ];
    }
}
