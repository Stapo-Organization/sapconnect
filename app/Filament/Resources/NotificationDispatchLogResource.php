<?php

namespace App\Filament\Resources;

use App\Filament\Resources\NotificationDispatchLogResource\Pages;
use App\Models\NotificationDispatchLog;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class NotificationDispatchLogResource extends Resource
{
    public static function canViewAny(): bool
    {
        return ! auth()->user()->hasAnyRole(['Branch Manager', 'Operator', 'Stakeholder']);
    }

    protected static ?string $model = NotificationDispatchLog::class;

    protected static ?string $navigationIcon = 'heroicon-o-bell-alert';

    public static function getNavigationLabel(): string
    {
        return 'سجل الإشعارات المُرسلة';
    }

    public static function getModelLabel(): string
    {
        return 'سجل إشعار';
    }

    public static function getPluralModelLabel(): string
    {
        return 'سجل الإشعارات المُرسلة';
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Settings');
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('event_key')
                    ->label('الحدث')
                    ->formatStateUsing(fn (string $state): string => config("notifications.events.{$state}.label", $state))
                    ->description(fn ($record) => $record->event_key)
                    ->searchable(),
                Tables\Columns\TextColumn::make('channels')
                    ->label('القنوات')
                    ->badge()
                    ->separator(','),
                Tables\Columns\TextColumn::make('recipients_count')
                    ->label('المستلمون')
                    ->numeric()
                    ->alignCenter(),
                Tables\Columns\TextColumn::make('email_count')
                    ->label('بريد')
                    ->numeric()
                    ->alignCenter()
                    ->toggleable(),
                Tables\Columns\TextColumn::make('push_tokens_count')
                    ->label('أجهزة Push')
                    ->numeric()
                    ->alignCenter(),
                Tables\Columns\TextColumn::make('title')
                    ->label('العنوان')
                    ->limit(40)
                    ->toggleable(),
                Tables\Columns\TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'success' => 'success',
                        'partial' => 'warning',
                        'failed'  => 'danger',
                        default   => 'gray',
                    }),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime()
                    ->since()
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('event_key')
                    ->label('الحدث')
                    ->options(fn () => collect(config('notifications.events', []))
                        ->mapWithKeys(fn ($def, $key) => [$key => $def['label'] ?? $key])
                        ->all()),
                Tables\Filters\SelectFilter::make('status')
                    ->label('الحالة')
                    ->options([
                        'success' => 'تم',
                        'partial' => 'جزئي',
                        'skipped' => 'تخطّي',
                        'failed'  => 'فشل',
                    ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListNotificationDispatchLogs::route('/'),
        ];
    }
}
