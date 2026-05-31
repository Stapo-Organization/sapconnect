<?php

namespace App\Filament\Resources;

use App\Models\SapInvoice;
use App\Filament\Resources\SapInvoiceResource\Pages;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class SapInvoiceResource extends Resource
{
    protected static ?string $model = SapInvoice::class;

    protected static ?string $navigationIcon = 'heroicon-o-document-text';
    protected static ?int $navigationSort = 1;

    public static function getNavigationLabel(): string { return __('Imported Invoices'); }
    public static function getModelLabel(): string { return __('Invoice'); }
    public static function getPluralModelLabel(): string { return __('Invoices'); }
    public static function getNavigationGroup(): ?string { return __('SAP Management'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Stakeholder']);
    }

    public static function shouldRegisterNavigation(): bool
    {
        return static::canViewAny();
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('doc_num')
                    ->label('رقم الفاتورة')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('card_code')
                    ->label('رمز العميل')
                    ->searchable(),
                Tables\Columns\TextColumn::make('sales_employee_code')
                    ->label('رمز المندوب')
                    ->searchable(),
                Tables\Columns\TextColumn::make('doc_total')
                    ->label('الإجمالي')
                    ->numeric()
                    ->sortable(),
                Tables\Columns\TextColumn::make('lines_count')
                    ->counts('lines')
                    ->label('عدد المنتجات')
                    ->badge(),
                Tables\Columns\TextColumn::make('doc_date')
                    ->label('التاريخ')
                    ->date()
                    ->sortable(),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('وقت الاستيراد')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('doc_num', 'desc')
            ->actions([
                Tables\Actions\ViewAction::make()->label('عرض التفاصيل'),
            ]);
    }

    public static function infolist(\Filament\Infolists\Infolist $infolist): \Filament\Infolists\Infolist
    {
        return $infolist
            ->schema([
                \Filament\Infolists\Components\Section::make('معلومات الفاتورة')
                    ->schema([
                        \Filament\Infolists\Components\TextEntry::make('doc_num')->label('رقم الفاتورة'),
                        \Filament\Infolists\Components\TextEntry::make('doc_date')->label('تاريخ الفاتورة'),
                        \Filament\Infolists\Components\TextEntry::make('card_code')->label('العميل'),
                        \Filament\Infolists\Components\TextEntry::make('sales_employee_code')->label('رقم المندوب'),
                    ])->columns(4),
                \Filament\Infolists\Components\Section::make('سطور الفاتورة (المنتجات)')
                    ->schema([
                        \Filament\Infolists\Components\RepeatableEntry::make('lines')
                            ->label('')
                            ->schema([
                                \Filament\Infolists\Components\TextEntry::make('item_code')->label('كود المنتج'),
                                \Filament\Infolists\Components\TextEntry::make('warehouse_code')->label('المستودع'),
                                \Filament\Infolists\Components\TextEntry::make('quantity')->label('الكمية'),
                            ])->columns(3)
                    ])
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSapInvoices::route('/'),
        ];
    }
}
