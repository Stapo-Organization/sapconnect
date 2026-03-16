<?php

namespace App\Filament\Widgets;

use App\Models\StockTransfer;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Illuminate\Database\Eloquent\Builder;

class PendingTransfersTable extends BaseWidget
{
    protected static ?string $heading = 'Transfers Pending Action (Urgent)';
    protected int | string | array $columnSpan = 'full';
    protected static ?int $sort = 5;

    public static function canView(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(
                StockTransfer::query()
                    ->where('internal_status', StockTransfer::STATUS_SHIPPED)
                    ->orderBy('sent_at', 'asc') // Oldest first (most urgent)
            )
            ->columns([
                Tables\Columns\TextColumn::make('doc_num')
                    ->label(__('Document Number'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('from_warehouse')
                    ->label(__('From')),
                Tables\Columns\TextColumn::make('to_warehouse')
                    ->label(__('To')),
                Tables\Columns\TextColumn::make('sent_at')
                    ->label(__('Shipped At'))
                    ->dateTime(),
                Tables\Columns\TextColumn::make('days_pending')
                    ->label(__('Days Pending'))
                    ->state(function (StockTransfer $record): string {
                        if (!$record->sent_at) return '-';
                        return (string) $record->sent_at->diffInDays(now()) . ' ' . __('Days');
                    })
                    ->badge()
                    ->color(function (StockTransfer $record): string {
                        if (!$record->sent_at) return 'gray';
                        $days = $record->sent_at->diffInDays(now());
                        if ($days > 3) return 'danger';
                        if ($days > 1) return 'warning';
                        return 'success';
                    }),
            ])
            ->actions([
                Tables\Actions\Action::make('view')
                    ->label(__('Manage'))
                    ->url(fn (StockTransfer $record): string => route('filament.admin.resources.stock-transfers.edit', ['record' => $record]))
                    ->icon('heroicon-m-eye'),
            ]);
    }
}
