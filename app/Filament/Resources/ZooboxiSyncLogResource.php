<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZooboxiSyncLogResource\Pages;
use App\Models\ZooboxiSyncLog;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Filament\Infolists;
use Filament\Infolists\Infolist;

class ZooboxiSyncLogResource extends Resource
{
    protected static ?string $model = ZooboxiSyncLog::class;

    protected static ?string $navigationIcon = 'heroicon-o-arrow-path';

    protected static ?string $slug = 'zooboxi-sync-logs';

    public static function getNavigationLabel(): string
    {
        return __('Sync Logs');
    }

    public static function getModelLabel(): string
    {
        return __('Sync Log');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Sync Logs');
    }

    public static function getNavigationGroup(): ?string
    {
        return '🛒 Zooboxi Store';
    }

    protected static ?int $navigationSort = 4;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('started_at', 'desc')
            ->poll('30s') // Auto-refresh every 30 seconds
            ->columns([
                Tables\Columns\TextColumn::make('sync_type')
                    ->label(__('Sync Type'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'products' => 'primary',
                        'stock' => 'success',
                        'prices' => 'warning',
                        'orders' => 'info',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'products' => '📦 ' . __('Products'),
                        'stock' => '📊 ' . __('Stock'),
                        'prices' => '💰 ' . __('Prices'),
                        'orders' => '🛒 ' . __('Orders'),
                        default => $state,
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('direction')
                    ->label(__('Direction'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'push' => 'info',
                        'pull' => 'warning',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'push' => '⬆️ Push',
                        'pull' => '⬇️ Pull',
                        default => $state,
                    }),

                Tables\Columns\TextColumn::make('status')
                    ->label(__('Status'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'completed' => 'success',
                        'running' => 'warning',
                        'failed' => 'danger',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'completed' => '✅ ' . __('Completed'),
                        'running' => '🔄 ' . __('Running'),
                        'failed' => '❌ ' . __('Failed'),
                        default => $state,
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('records_total')
                    ->label(__('Total'))
                    ->numeric()
                    ->alignCenter()
                    ->placeholder('-'),

                Tables\Columns\TextColumn::make('records_synced')
                    ->label(__('Synced'))
                    ->numeric()
                    ->alignCenter()
                    ->color('success')
                    ->placeholder('-'),

                Tables\Columns\TextColumn::make('records_failed')
                    ->label(__('Failed'))
                    ->numeric()
                    ->alignCenter()
                    ->color(fn ($state) => $state > 0 ? 'danger' : 'gray')
                    ->placeholder('-'),

                Tables\Columns\TextColumn::make('duration')
                    ->label(__('Duration'))
                    ->state(function (ZooboxiSyncLog $record) {
                        $duration = $record->duration;
                        if ($duration === null) return __('Running...');
                        if ($duration < 60) return $duration . 's';
                        return floor($duration / 60) . 'm ' . ($duration % 60) . 's';
                    })
                    ->alignCenter(),

                Tables\Columns\TextColumn::make('error_message')
                    ->label(__('Error'))
                    ->limit(50)
                    ->tooltip(fn (ZooboxiSyncLog $record) => $record->error_message)
                    ->color('danger')
                    ->placeholder('-')
                    ->toggleable(),

                Tables\Columns\TextColumn::make('started_at')
                    ->label(__('Started'))
                    ->dateTime('Y-m-d H:i:s')
                    ->sortable(),

                Tables\Columns\TextColumn::make('completed_at')
                    ->label(__('Completed'))
                    ->dateTime('Y-m-d H:i:s')
                    ->placeholder(__('In Progress'))
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('sync_type')
                    ->label(__('Sync Type'))
                    ->options([
                        'products' => __('Products'),
                        'stock' => __('Stock'),
                        'prices' => __('Prices'),
                        'orders' => __('Orders'),
                    ]),

                Tables\Filters\SelectFilter::make('status')
                    ->label(__('Status'))
                    ->options([
                        'completed' => __('Completed'),
                        'running' => __('Running'),
                        'failed' => __('Failed'),
                    ]),

                Tables\Filters\SelectFilter::make('direction')
                    ->label(__('Direction'))
                    ->options([
                        'push' => 'Push (→ WooCommerce)',
                        'pull' => 'Pull (← WooCommerce)',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Section::make(__('Sync Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('sync_type')
                            ->label(__('Sync Type'))
                            ->badge(),
                        Infolists\Components\TextEntry::make('direction')
                            ->label(__('Direction'))
                            ->badge(),
                        Infolists\Components\TextEntry::make('status')
                            ->label(__('Status'))
                            ->badge()
                            ->color(fn (string $state): string => match ($state) {
                                'completed' => 'success',
                                'running' => 'warning',
                                'failed' => 'danger',
                                default => 'gray',
                            }),
                        Infolists\Components\TextEntry::make('started_at')
                            ->label(__('Started At'))
                            ->dateTime(),
                        Infolists\Components\TextEntry::make('completed_at')
                            ->label(__('Completed At'))
                            ->dateTime()
                            ->placeholder(__('In Progress')),
                        Infolists\Components\TextEntry::make('duration')
                            ->label(__('Duration'))
                            ->state(function (ZooboxiSyncLog $record) {
                                $duration = $record->duration;
                                if ($duration === null) return __('Running...');
                                if ($duration < 60) return $duration . ' seconds';
                                return floor($duration / 60) . 'm ' . ($duration % 60) . 's';
                            }),
                    ])->columns(3),

                Infolists\Components\Section::make(__('Records'))
                    ->schema([
                        Infolists\Components\TextEntry::make('records_total')
                            ->label(__('Total Records'))
                            ->numeric()
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('records_synced')
                            ->label(__('Successfully Synced'))
                            ->numeric()
                            ->color('success')
                            ->placeholder('-'),
                        Infolists\Components\TextEntry::make('records_failed')
                            ->label(__('Failed'))
                            ->numeric()
                            ->color(fn ($state) => $state > 0 ? 'danger' : 'gray')
                            ->placeholder('-'),
                    ])->columns(3),

                Infolists\Components\Section::make(__('Error Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('error_message')
                            ->label(__('Error Message'))
                            ->columnSpanFull()
                            ->placeholder(__('No errors')),
                    ])
                    ->visible(fn (ZooboxiSyncLog $record) => !empty($record->error_message)),

                Infolists\Components\Section::make(__('Additional Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('details')
                            ->label(__('Details (JSON)'))
                            ->state(fn (ZooboxiSyncLog $record) => $record->details ? json_encode($record->details, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) : null)
                            ->columnSpanFull()
                            ->placeholder(__('No additional details'))
                            ->markdown(),
                    ])
                    ->collapsible()
                    ->collapsed(),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZooboxiSyncLogs::route('/'),
        ];
    }
}
