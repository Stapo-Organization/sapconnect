<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SapCreditMemoResource\Pages;
use App\Models\SapCreditMemo;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Infolists\Infolist;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\RepeatableEntry;

class SapCreditMemoResource extends Resource
{
    protected static ?string $model = SapCreditMemo::class;

    protected static ?string $navigationIcon = 'heroicon-o-receipt-refund';
    protected static ?int $navigationSort = 2;

    public static function getNavigationLabel(): string { return __('Imported Credit Memos'); }
    public static function getModelLabel(): string { return __('Credit Memo'); }
    public static function getPluralModelLabel(): string { return __('Credit Memos'); }
    public static function getNavigationGroup(): ?string { return __('SAP Management'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Stakeholder']);
    }

    public static function shouldRegisterNavigation(): bool
    {
        return static::canViewAny();
    }

    public static function form(Form $form): Form
    {
        return $form->schema([]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('doc_num')
                    ->label('Doc Number')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('card_code')
                    ->label('Customer Code')
                    ->searchable(),
                Tables\Columns\TextColumn::make('sales_employee_code')
                    ->label('Sales Employee')
                    ->searchable(),
                Tables\Columns\TextColumn::make('doc_date')
                    ->label('Date')
                    ->date()
                    ->sortable(),
                Tables\Columns\TextColumn::make('doc_total')
                    ->label('Total (SAR)')
                    ->sortable()
                    ->money('SAR'),
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Section::make('Credit Memo Details')
                    ->schema([
                        TextEntry::make('doc_num')->label('Document Number'),
                        TextEntry::make('doc_date')->label('Date')->date(),
                        TextEntry::make('card_code')->label('Customer Code'),
                        TextEntry::make('sales_employee_code')->label('Sales Employee Code'),
                        TextEntry::make('doc_total')->label('Total Amount')->money('SAR'),
                    ])->columns(3),

                Section::make('Returned Items')
                    ->schema([
                        RepeatableEntry::make('lines')
                            ->label('')
                            ->schema([
                                TextEntry::make('item_code')->label('Item Code'),
                                TextEntry::make('item_description')->label('Description'),
                                TextEntry::make('warehouse_code')->label('Warehouse'),
                                TextEntry::make('quantity')->label('Qty'),
                                TextEntry::make('price')->label('Price')->money('SAR'),
                            ])
                            ->columns(5)
                    ])
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSapCreditMemos::route('/'),
            'view' => Pages\ViewSapCreditMemo::route('/{record}'),
        ];
    }
}
