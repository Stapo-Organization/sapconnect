<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MrsoolDeliveryResource\Pages;
use App\Models\MrsoolDelivery;
use Filament\Forms\Form;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Read-only board of every Mrsool (مرسول) courier request.
 *
 * Deliberately view-only: deliveries are created by branch managers from the
 * app and driven by the Mrsool API/webhook — editing one here would desync the
 * ledger from the courier's real state.
 */
class MrsoolDeliveryResource extends Resource
{
    protected static ?string $model = MrsoolDelivery::class;

    protected static ?string $navigationIcon = 'heroicon-o-truck';

    protected static ?string $slug = 'mrsool-deliveries';

    protected static ?int $navigationSort = 4;

    public static function getNavigationLabel(): string
    {
        return 'توصيلات مرسول';
    }

    public static function getModelLabel(): string
    {
        return 'توصيلة مرسول';
    }

    public static function getPluralModelLabel(): string
    {
        return 'توصيلات مرسول';
    }

    public static function getNavigationGroup(): ?string
    {
        return '🛒 Zooboxi Store';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit($record): bool
    {
        return false;
    }

    public static function canDelete($record): bool
    {
        return false;
    }

    public static function canDeleteAny(): bool
    {
        return false;
    }

    public static function getNavigationBadge(): ?string
    {
        $active = static::getModel()::query()->active()->count();

        return $active > 0 ? (string) $active : null;
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'info';
    }

    public static function form(Form $form): Form
    {
        return $form->schema([]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('id', 'desc')
            ->columns([
                Tables\Columns\TextColumn::make('partner_order_id')
                    ->label('رقم الطلب')
                    ->searchable()
                    ->copyable()
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('order.warehouse_code')
                    ->label('الفرع')
                    ->badge()
                    ->sortable(),

                Tables\Columns\TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->formatStateUsing(fn (?string $state): string => MrsoolDelivery::labelFor($state) ?? '-')
                    ->color(fn ($record): string => match ($record->phase) {
                        MrsoolDelivery::PHASE_DELIVERED => 'success',
                        MrsoolDelivery::PHASE_FAILED => 'danger',
                        MrsoolDelivery::PHASE_IN_TRANSIT => 'info',
                        MrsoolDelivery::PHASE_ASSIGNED => 'warning',
                        default => 'gray',
                    }),

                Tables\Columns\TextColumn::make('courier_name')
                    ->label('المندوب')
                    ->description(fn ($record): ?string => $record->courier_phone)
                    ->placeholder('-'),

                Tables\Columns\TextColumn::make('price_quote')
                    ->label('السعر')
                    ->money('SAR')
                    ->placeholder('-'),

                Tables\Columns\TextColumn::make('requested_at')
                    ->label('وقت الطلب')
                    ->dateTime()
                    ->sortable(),

                Tables\Columns\TextColumn::make('delivered_at')
                    ->label('وقت التوصيل')
                    ->dateTime()
                    ->placeholder('-')
                    ->sortable(),

                Tables\Columns\TextColumn::make('last_error')
                    ->label('الخطأ')
                    ->limit(40)
                    ->color('danger')
                    ->placeholder('-')
                    ->toggleable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('phase')
                    ->label('المرحلة')
                    ->options([
                        MrsoolDelivery::PHASE_SEARCHING  => 'جارٍ البحث عن مندوب',
                        MrsoolDelivery::PHASE_ASSIGNED   => 'تم تعيين مندوب',
                        MrsoolDelivery::PHASE_IN_TRANSIT => 'في الطريق',
                        MrsoolDelivery::PHASE_DELIVERED  => 'تم التوصيل',
                        MrsoolDelivery::PHASE_FAILED     => 'تعذّر',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Infolists\Components\Section::make('التوصيلة')
                ->columns(3)
                ->schema([
                    Infolists\Components\TextEntry::make('partner_order_id')->label('رقم الطلب'),
                    Infolists\Components\TextEntry::make('mrsool_order_id')->label('رقم مرسول')->placeholder('-'),
                    Infolists\Components\TextEntry::make('environment')->label('البيئة')->badge(),
                    Infolists\Components\TextEntry::make('status')
                        ->label('الحالة')
                        ->formatStateUsing(fn (?string $state): string => MrsoolDelivery::labelFor($state) ?? '-'),
                    Infolists\Components\TextEntry::make('phase')->label('المرحلة')->badge(),
                    Infolists\Components\TextEntry::make('price_quote')->label('السعر')->money('SAR')->placeholder('-'),
                    Infolists\Components\TextEntry::make('courier_name')->label('المندوب')->placeholder('-'),
                    Infolists\Components\TextEntry::make('courier_phone')->label('جوال المندوب')->placeholder('-'),
                    Infolists\Components\TextEntry::make('last_error')->label('الخطأ')->color('danger')->placeholder('-'),
                ]),

            Infolists\Components\Section::make('التوقيتات')
                ->columns(3)
                ->schema([
                    Infolists\Components\TextEntry::make('requested_at')->label('الطلب')->dateTime(),
                    Infolists\Components\TextEntry::make('assigned_at')->label('التعيين')->dateTime()->placeholder('-'),
                    Infolists\Components\TextEntry::make('picked_up_at')->label('الاستلام')->dateTime()->placeholder('-'),
                    Infolists\Components\TextEntry::make('delivered_at')->label('التوصيل')->dateTime()->placeholder('-'),
                    Infolists\Components\TextEntry::make('failed_at')->label('التعذّر')->dateTime()->placeholder('-'),
                    Infolists\Components\TextEntry::make('last_synced_at')->label('آخر مزامنة')->dateTime()->placeholder('-'),
                ]),

            Infolists\Components\Section::make('سجل الأحداث')
                ->schema([
                    Infolists\Components\RepeatableEntry::make('events')
                        ->label('')
                        ->schema([
                            Infolists\Components\TextEntry::make('event')
                                ->label('الحدث')
                                ->formatStateUsing(fn (?string $state): string => MrsoolDelivery::labelFor($state) ?? '-'),
                            Infolists\Components\TextEntry::make('created_at')->label('الوقت'),
                        ])
                        ->columns(2),
                ]),
        ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListMrsoolDeliveries::route('/'),
            'view'  => Pages\ViewMrsoolDelivery::route('/{record}'),
        ];
    }
}
