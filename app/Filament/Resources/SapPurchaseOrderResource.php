<?php

namespace App\Filament\Resources;

use App\Models\PurchaseOrder;
use App\Filament\Resources\SapPurchaseOrderResource\Pages;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class SapPurchaseOrderResource extends Resource
{
    protected static ?string $model = PurchaseOrder::class;

    protected static ?string $navigationIcon = 'heroicon-o-shopping-cart';
    protected static ?int $navigationSort = 2;

    public static function getNavigationLabel(): string { return __('Imported Purchase Orders'); }
    public static function getModelLabel(): string { return __('Purchase Order'); }
    public static function getPluralModelLabel(): string { return __('Purchase Orders'); }
    public static function getNavigationGroup(): ?string { return __('SAP Management'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Stakeholder']);
    }

    public static function shouldRegisterNavigation(): bool
    {
        return static::canViewAny();
    }

    // Read-only: no create/edit/delete
    public static function canCreate(): bool { return false; }

    public static function table(Table $table): Table
    {
        return $table
            ->query(PurchaseOrder::query()->whereNotNull('sap_doc_entry'))
            ->columns([
                Tables\Columns\TextColumn::make('sap_doc_num')
                    ->label('SAP Doc#')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('supplier.sap_code')
                    ->label('Vendor Code')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('supplier.name')
                    ->label('Supplier')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('computed_brands')
                    ->label('Brand(s)')
                    ->badge()
                    ->color('info')
                    ->default('—'),
                Tables\Columns\TextColumn::make('currency')
                    ->label('Currency'),
                Tables\Columns\TextColumn::make('po_value')
                    ->label('PO Value')
                    ->money(fn ($record) => $record->currency ?? 'SAR')
                    ->sortable(),
                Tables\Columns\TextColumn::make('lines_count')
                    ->counts('lines')
                    ->label('Items')
                    ->badge(),
                Tables\Columns\TextColumn::make('doc_date')
                    ->label('Doc Date')
                    ->date()
                    ->sortable(),
                Tables\Columns\BadgeColumn::make('doc_status')
                    ->label('Status')
                    ->colors([
                        'success' => 'Open',
                        'gray' => 'Closed',
                        'warning' => 'Delivered',
                        'info' => 'Paid',
                    ]),
            ])
            ->defaultSort('sap_doc_num', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('supplier_id')
                    ->relationship('supplier', 'name')
                    ->searchable()
                    ->preload()
                    ->label('Supplier'),
                Tables\Filters\SelectFilter::make('brand_id')
                    ->relationship('brand', 'name')
                    ->searchable()
                    ->preload()
                    ->label('Brand'),
                Tables\Filters\SelectFilter::make('doc_status')
                    ->options([
                        'Open' => 'Open',
                        'Closed' => 'Closed',
                    ])
                    ->label('Status'),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('View Details'),
            ]);
    }

    public static function infolist(\Filament\Infolists\Infolist $infolist): \Filament\Infolists\Infolist
    {
        return $infolist
            ->schema([
                \Filament\Infolists\Components\Section::make('PO Header')
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('sap_doc_num')->label('SAP Doc#'),
                        \Filament\Infolists\Components\TextEntry::make('sap_doc_entry')->label('SAP DocEntry'),
                        \Filament\Infolists\Components\TextEntry::make('supplier.name')->label('Supplier'),
                        \Filament\Infolists\Components\TextEntry::make('computed_brands')
                            ->label('Brand(s)')
                            ->badge()
                            ->color('info')
                            ->default('—'),
                        \Filament\Infolists\Components\TextEntry::make('currency')->label('Currency'),
                        \Filament\Infolists\Components\TextEntry::make('po_value')->label('PO Value'),
                        \Filament\Infolists\Components\TextEntry::make('doc_date')->label('Doc Date')->date(),
                        \Filament\Infolists\Components\TextEntry::make('doc_due_date')->label('Due Date')->date(),
                        \Filament\Infolists\Components\TextEntry::make('doc_status')->label('Status')->badge(),
                        \Filament\Infolists\Components\TextEntry::make('comments')->label('Comments'),
                    ])->columns(4),
                \Filament\Infolists\Components\Section::make('PO Lines (Items)')
                    ->schema([
                        \Filament\Infolists\Components\RepeatableEntry::make('lines')
                            ->label('')
                            ->schema([
                                \Filament\Infolists\Components\TextEntry::make('item_code')->label('Item Code'),
                                \Filament\Infolists\Components\TextEntry::make('description')->label('Description'),
                                \Filament\Infolists\Components\TextEntry::make('quantity')->label('Qty'),
                                \Filament\Infolists\Components\TextEntry::make('unit_price')->label('Unit Price'),
                                \Filament\Infolists\Components\TextEntry::make('total_price')->label('Total'),
                                \Filament\Infolists\Components\TextEntry::make('warehouse_code')->label('Warehouse'),
                            ])->columns(6)
                    ])
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSapPurchaseOrders::route('/'),
        ];
    }
}
