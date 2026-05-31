<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ProductResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Product;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Filament\Infolists;
use Filament\Infolists\Infolist;

class ProductResource extends Resource
{
    use ReadOnlyStakeholder;

    public static function canViewAny(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected static ?string $model = Product::class;

    protected static ?string $navigationIcon = 'heroicon-o-cube';

    public static function getNavigationLabel(): string
    {
        return __('Products');
    }

    public static function getModelLabel(): string
    {
        return __('Product');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Products');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Master Data');
    }

    protected static ?int $navigationSort = 2; // After Brands (which is likely 1)

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('item_code')
                    ->label(__('Item Code'))
                    ->required()
                    ->maxLength(255),
                Forms\Components\TextInput::make('item_name')
                    ->label(__('Item Name'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('foreign_name')
                    ->label(__('Foreign Name'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('items_group_code')
                    ->label(__('Items Group Code'))
                    ->numeric(),
                Forms\Components\TextInput::make('inventory_uom')
                    ->label(__('Inventory UOM'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('piece_barcode')
                    ->label(__('Piece Barcode'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('sales_items_per_unit')
                    ->label(__('Sales Items Per Unit'))
                    ->numeric(),
                Forms\Components\DateTimePicker::make('create_date')
                    ->label(__('Create Date'))
                    ->disabled(),
                Forms\Components\DateTimePicker::make('update_date')
                    ->label(__('Update Date'))
                    ->disabled(),
                Forms\Components\Select::make('source')
                    ->label(__('Source'))
                    ->options([
                        'production' => __('Production'),
                    ])
                    ->required(),
                Forms\Components\Repeater::make('prices')
                    ->label(__('Item Prices'))
                    ->schema([
                        Forms\Components\TextInput::make('PriceList')
                            ->label(__('Price List ID'))
                            ->disabled(),
                        Forms\Components\TextInput::make('Price')
                            ->label(__('Price'))
                            ->numeric()
                            ->disabled(),
                        Forms\Components\TextInput::make('Currency')
                            ->label(__('Currency'))
                            ->disabled(),
                    ])
                    ->columns(3)
                    ->collapsible()
                    ->itemLabel(fn (array $state): ?string => isset($state['PriceList']) ? __('Price List ID') . ': ' . $state['PriceList'] : null)
                    ->disableItemCreation()
                    ->disableItemDeletion()
                    ->disableItemMovement()
                    ->columnSpanFull(),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(function (Builder $query) {
                return $query->where('source', 'production');
            })
            ->columns([
                Tables\Columns\ImageColumn::make('product_image')
                    ->label(__('Image'))
                    ->alignCenter()
                    ->state(function (Product $record) {
                        $code = $record->item_code;
                        if (empty($code))
                            return null;
                        $folder = substr($code, 0, 4);
                        return "https://ppte.sa/img/{$folder}/{$code}.png";
                    })
                    ->url(fn($state) => $state)
                    ->openUrlInNewTab(),
                Tables\Columns\TextColumn::make('item_code')
                    ->label(__('Item Code'))
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('item_name')
                    ->label(__('Item Name'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('foreign_name')
                    ->label(__('Foreign Name'))
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('items_group_code')
                    ->label(__('Items Group Code'))
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('inventory_uom')
                    ->label(__('Inventory UOM'))
                    ->searchable()
                    ->toggleable(),
                Tables\Columns\TextColumn::make('piece_barcode')
                    ->label(__('Piece Barcode'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('sales_items_per_unit')
                    ->label(__('Sales Items Per Unit')),
                Tables\Columns\TextColumn::make('u_portal_sync')
                    ->label(__('Portal Sync'))
                    ->searchable()
                    ->sortable()
                    ->badge(),
                Tables\Columns\TextColumn::make('create_date')
                    ->label(__('Create Date'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('update_date')
                    ->label(__('Update Date'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
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
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('source')
                    ->label(__('Source'))
                    ->options([
                        'production' => __('Production'),
                    ]),
                Tables\Filters\SelectFilter::make('u_portal_sync')
                    ->label(__('Portal Sync'))
                    ->options(fn () => \App\Models\Product::whereNotNull('u_portal_sync')->where('u_portal_sync', '!=', '')->distinct()->pluck('u_portal_sync', 'u_portal_sync')->toArray()),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Section::make(__('Product Details'))
                    ->schema([
                        Infolists\Components\ImageEntry::make('product_image')
                            ->label(__('Image'))
                            ->state(function (Product $record) {
                                $code = $record->item_code;
                                if (empty($code)) return null;
                                $folder = substr($code, 0, 4);
                                return "https://ppte.sa/img/{$folder}/{$code}.png";
                            }),
                        Infolists\Components\TextEntry::make('item_code')
                            ->label(__('Item Code')),
                        Infolists\Components\TextEntry::make('item_name')
                            ->label(__('Item Name')),
                        Infolists\Components\TextEntry::make('foreign_name')
                            ->label(__('Foreign Name')),
                        Infolists\Components\TextEntry::make('items_group_code')
                            ->label(__('Items Group Code')),
                        Infolists\Components\TextEntry::make('sales_items_per_unit')
                            ->label(__('Sales Items Per Unit')),
                    ])->columns(2),

                Infolists\Components\Section::make(__('Item Prices'))
                    ->schema([
                        Infolists\Components\RepeatableEntry::make('prices')
                            ->label('')
                            ->schema([
                                Infolists\Components\Grid::make(3)
                                    ->schema([
                                        Infolists\Components\TextEntry::make('PriceList')
                                            ->label(__('Price List ID'))
                                            ->inlineLabel(),
                                        Infolists\Components\TextEntry::make('Price')
                                            ->label(__('Price'))
                                            ->inlineLabel(),
                                        Infolists\Components\TextEntry::make('Currency')
                                            ->label(__('Currency'))
                                            ->inlineLabel(),
                                    ])
                            ])
                            ->columns(1)
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
            'index' => Pages\ListProducts::route('/'),
            'create' => Pages\CreateProduct::route('/create'),
            'edit' => Pages\EditProduct::route('/{record}/edit'),
        ];
    }
}
