<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZooboxiProductResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Product;
use App\Models\Brand;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Filament\Infolists;
use Filament\Infolists\Infolist;

class ZooboxiProductResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = Product::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-bag';

    protected static ?string $slug = 'zooboxi-products';

    public static function getNavigationLabel(): string
    {
        return __('Zooboxi Products');
    }

    public static function getModelLabel(): string
    {
        return __('Product');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Zooboxi Products');
    }

    public static function getNavigationGroup(): ?string
    {
        return '🛒 Zooboxi Store';
    }

    protected static ?int $navigationSort = 1;

    public static function getNavigationBadge(): ?string
    {
        return static::getModel()::where('zooboxi_active', true)->count();
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'success';
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Zooboxi Settings'))
                    ->schema([
                        Forms\Components\Toggle::make('zooboxi_active')
                            ->label(__('Active in Zooboxi Store'))
                            ->helperText(__('Enable to display this product in the Zooboxi store')),
                        Forms\Components\Toggle::make('woo_sync')
                            ->label(__('WooCommerce Sync'))
                            ->helperText(__('Enable WooCommerce synchronization')),
                        Forms\Components\TextInput::make('woo_product_id')
                            ->label(__('WooCommerce Product ID'))
                            ->disabled()
                            ->numeric(),
                    ])->columns(3),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(function (Builder $query) {
                return $query->where('source', 'production')
                    ->where('zooboxi_active', true);
            })
            ->defaultSort('zb_name_ar', 'asc')
            ->columns([
                Tables\Columns\ImageColumn::make('product_image')
                    ->label(__('Image'))
                    ->alignCenter()
                    ->state(function (Product $record) {
                        // Prefer ZID images, fallback to holeno
                        $images = $record->zb_images;
                        if (!empty($images) && is_array($images)) {
                            return $images[0];
                        }
                        $code = $record->item_code;
                        return $code ? 'https://gal.holeno.com/imghd/' . $code . '.png' : null;
                    })
                    ->circular()
                    ->size(40),

                Tables\Columns\TextColumn::make('item_code')
                    ->label(__('Item Code'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->weight('bold')
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('zb_name_ar')
                    ->label(__('اسم المنتج'))
                    ->searchable()
                    ->sortable()
                    ->limit(40)
                    ->tooltip(fn (Product $record) => $record->zb_name_ar),

                Tables\Columns\TextColumn::make('zb_name_en')
                    ->label(__('Product Name'))
                    ->searchable()
                    ->limit(35)
                    ->tooltip(fn (Product $record) => $record->zb_name_en)
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('brand.name')
                    ->label(__('Brand'))
                    ->sortable()
                    ->searchable()
                    ->toggleable(),

                Tables\Columns\TextColumn::make('zb_categories_ar')
                    ->label(__('التصنيفات'))
                    ->limit(30)
                    ->tooltip(fn (Product $record) => $record->zb_categories_ar)
                    ->toggleable(),

                Tables\Columns\TextColumn::make('piece_barcode')
                    ->label(__('Barcode'))
                    ->searchable()
                    ->copyable()
                    ->toggleable(),

                Tables\Columns\TextColumn::make('retail_price')
                    ->label(__('Price (SAR)'))
                    ->state(function (Product $record) {
                        if (!$record->prices) return '-';
                        $price1 = collect($record->prices)->firstWhere('PriceList', 1);
                        return $price1 ? number_format($price1['Price'], 2) : '-';
                    })
                    ->alignEnd(),

                Tables\Columns\TextColumn::make('total_stock')
                    ->label(__('Total Stock'))
                    ->state(function (Product $record) {
                        return $record->warehouseStocks()->sum('in_stock');
                    })
                    ->numeric()
                    ->alignCenter()
                    ->color(fn ($state) => $state > 0 ? 'success' : 'danger'),

                Tables\Columns\IconColumn::make('has_description')
                    ->label(__('وصف'))
                    ->state(fn (Product $record) => !empty($record->zb_description_ar))
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('gray')
                    ->alignCenter()
                    ->toggleable(),

                Tables\Columns\IconColumn::make('has_images')
                    ->label(__('صور'))
                    ->state(fn (Product $record) => !empty($record->zb_images))
                    ->boolean()
                    ->trueIcon('heroicon-o-photo')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('gray')
                    ->alignCenter()
                    ->toggleable(),

                Tables\Columns\IconColumn::make('woo_sync')
                    ->label(__('WC Sync'))
                    ->boolean()
                    ->trueIcon('heroicon-o-check-circle')
                    ->falseIcon('heroicon-o-x-circle')
                    ->trueColor('success')
                    ->falseColor('gray')
                    ->alignCenter()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('items_group_code')
                    ->label(__('Brand'))
                    ->relationship('brand', 'name')
                    ->searchable()
                    ->preload(),

                Tables\Filters\Filter::make('has_description')
                    ->label(__('Has Description'))
                    ->query(fn (Builder $query) => $query->whereNotNull('zb_description_ar')->where('zb_description_ar', '!=', '')),

                Tables\Filters\Filter::make('no_description')
                    ->label(__('Missing Description'))
                    ->query(fn (Builder $query) => $query->where(fn ($q) => $q->whereNull('zb_description_ar')->orWhere('zb_description_ar', ''))),

                Tables\Filters\Filter::make('has_images')
                    ->label(__('Has Images'))
                    ->query(fn (Builder $query) => $query->whereNotNull('zb_images')),

                Tables\Filters\Filter::make('has_stock')
                    ->label(__('In Stock'))
                    ->query(fn (Builder $query) => $query->whereHas('warehouseStocks', fn ($q) => $q->where('in_stock', '>', 0))),

                Tables\Filters\Filter::make('out_of_stock')
                    ->label(__('Out of Stock'))
                    ->query(fn (Builder $query) => $query->whereDoesntHave('warehouseStocks', fn ($q) => $q->where('in_stock', '>', 0))),

                Tables\Filters\SelectFilter::make('u_proprt1')
                    ->label(__('Category 1'))
                    ->options(fn () => Product::where('zooboxi_active', true)
                        ->whereNotNull('u_proprt1')
                        ->where('u_proprt1', '!=', '')
                        ->distinct()
                        ->pluck('u_proprt1', 'u_proprt1')
                        ->toArray()),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\BulkAction::make('enable_woo_sync')
                        ->label(__('Enable WC Sync'))
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->requiresConfirmation()
                        ->deselectRecordsAfterCompletion()
                        ->action(fn ($records) => $records->each(fn ($r) => $r->update(['woo_sync' => true]))),

                    Tables\Actions\BulkAction::make('disable_woo_sync')
                        ->label(__('Disable WC Sync'))
                        ->icon('heroicon-o-x-circle')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->deselectRecordsAfterCompletion()
                        ->action(fn ($records) => $records->each(fn ($r) => $r->update(['woo_sync' => false]))),
                ]),
            ]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                // ZID Product Info (primary)
                Infolists\Components\Section::make(__('معلومات المنتج'))
                    ->schema([
                        Infolists\Components\ImageEntry::make('product_images')
                            ->label(__('صور المنتج'))
                            ->state(function (Product $record) {
                                $images = $record->zb_images;
                                if (!empty($images) && is_array($images)) {
                                    return $images;
                                }
                                return ['https://gal.holeno.com/imghd/' . $record->item_code . '.png'];
                            })
                            ->columnSpanFull()
                            ->stacked()
                            ->overlap(3)
                            ->limit(5)
                            ->size(80),

                        Infolists\Components\TextEntry::make('zb_name_ar')
                            ->label(__('الاسم العربي'))
                            ->size(Infolists\Components\TextEntry\TextEntrySize::Large)
                            ->weight('bold')
                            ->columnSpanFull(),

                        Infolists\Components\TextEntry::make('zb_name_en')
                            ->label(__('English Name'))
                            ->columnSpanFull(),

                        Infolists\Components\TextEntry::make('item_code')
                            ->label(__('Item Code'))
                            ->copyable(),
                        Infolists\Components\TextEntry::make('piece_barcode')
                            ->label(__('Barcode'))
                            ->copyable(),
                        Infolists\Components\TextEntry::make('brand.name')
                            ->label(__('Brand')),
                        Infolists\Components\TextEntry::make('inventory_uom')
                            ->label(__('UOM')),

                        Infolists\Components\TextEntry::make('zb_categories_ar')
                            ->label(__('التصنيفات'))
                            ->columnSpanFull(),

                        Infolists\Components\TextEntry::make('zb_keywords')
                            ->label(__('كلمات مفتاحية'))
                            ->badge()
                            ->separator(',')
                            ->columnSpanFull(),

                        Infolists\Components\TextEntry::make('zb_weight')
                            ->label(__('الوزن'))
                            ->state(fn (Product $record) => $record->zb_weight
                                ? $record->zb_weight . ' ' . ($record->zb_weight_unit ?? '')
                                : '-'),
                    ])->columns(4),

                // Descriptions
                Infolists\Components\Section::make(__('الوصف'))
                    ->schema([
                        Infolists\Components\TextEntry::make('zb_short_description_ar')
                            ->label(__('وصف مختصر'))
                            ->html()
                            ->columnSpanFull()
                            ->placeholder(__('لا يوجد')),

                        Infolists\Components\TextEntry::make('zb_description_ar')
                            ->label(__('الوصف الكامل (عربي)'))
                            ->html()
                            ->columnSpanFull()
                            ->placeholder(__('لا يوجد وصف')),

                        Infolists\Components\TextEntry::make('zb_description_en')
                            ->label(__('Full Description (EN)'))
                            ->html()
                            ->columnSpanFull()
                            ->placeholder(__('No description'))
                            ->hidden(fn (Product $record) => empty($record->zb_description_en)),
                    ])->collapsible(),

                // SEO
                Infolists\Components\Section::make(__('SEO'))
                    ->schema([
                        Infolists\Components\TextEntry::make('zb_seo_title_ar')
                            ->label(__('عنوان SEO (عربي)'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('zb_seo_title_en')
                            ->label(__('SEO Title (EN)'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('zb_seo_description_ar')
                            ->label(__('وصف SEO (عربي)'))
                            ->columnSpanFull()
                            ->placeholder('-'),
                    ])->columns(2)
                    ->collapsible()
                    ->collapsed(),

                // SAP Reference
                Infolists\Components\Section::make(__('SAP Reference'))
                    ->schema([
                        Infolists\Components\TextEntry::make('item_name')
                            ->label(__('SAP Item Name')),
                        Infolists\Components\TextEntry::make('foreign_name')
                            ->label(__('SAP Foreign Name')),
                        Infolists\Components\TextEntry::make('u_proprt1')
                            ->label(__('Category 1'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('u_proprt2')
                            ->label(__('Category 2'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('u_proprt3')
                            ->label(__('Category 3'))
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('u_proprt4')
                            ->label(__('Category 4'))
                            ->placeholder('-'),
                    ])->columns(3)
                    ->collapsible()
                    ->collapsed(),

                // WooCommerce Sync
                Infolists\Components\Section::make(__('WooCommerce Sync'))
                    ->schema([
                        Infolists\Components\IconEntry::make('zooboxi_active')
                            ->label(__('Zooboxi Active'))
                            ->boolean(),
                        Infolists\Components\IconEntry::make('woo_sync')
                            ->label(__('WC Sync Enabled'))
                            ->boolean(),
                        Infolists\Components\TextEntry::make('woo_product_id')
                            ->label(__('WooCommerce Product ID'))
                            ->placeholder(__('Not synced yet')),
                        Infolists\Components\TextEntry::make('woo_synced_at')
                            ->label(__('Last Synced'))
                            ->dateTime()
                            ->placeholder(__('Never')),
                    ])->columns(4),

                // Prices
                Infolists\Components\Section::make(__('Item Prices'))
                    ->schema([
                        Infolists\Components\RepeatableEntry::make('prices')
                            ->label('')
                            ->schema([
                                Infolists\Components\Grid::make(3)
                                    ->schema([
                                        Infolists\Components\TextEntry::make('PriceList')
                                            ->label(__('Price List'))
                                            ->inlineLabel(),
                                        Infolists\Components\TextEntry::make('Price')
                                            ->label(__('Price'))
                                            ->inlineLabel()
                                            ->money('SAR'),
                                        Infolists\Components\TextEntry::make('Currency')
                                            ->label(__('Currency'))
                                            ->inlineLabel(),
                                    ])
                            ])
                            ->columns(1)
                    ])
                    ->collapsible()
                    ->collapsed(),

                // Warehouse Stock
                Infolists\Components\Section::make(__('Warehouse Stock'))
                    ->schema([
                        Infolists\Components\RepeatableEntry::make('warehouseStocks')
                            ->label('')
                            ->schema([
                                Infolists\Components\TextEntry::make('warehouse_code')
                                    ->label(__('Warehouse')),
                                Infolists\Components\TextEntry::make('in_stock')
                                    ->label(__('In Stock'))
                                    ->numeric()
                                    ->color(fn ($state) => $state > 0 ? 'success' : 'danger'),
                                Infolists\Components\TextEntry::make('ordered')
                                    ->label(__('Ordered'))
                                    ->numeric(),
                            ])
                            ->columns(3)
                    ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZooboxiProducts::route('/'),
            'view' => Pages\ViewZooboxiProduct::route('/{record}'),
            'edit' => Pages\EditZooboxiProduct::route('/{record}/edit'),
        ];
    }
}
