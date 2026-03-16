<?php

namespace App\Filament\Widgets;

use App\Models\AutomationLog;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Illuminate\Database\Eloquent\Builder;

class AutomationHealthLogTable extends BaseWidget
{
    protected static ?string $heading = 'SAP Sync Automations Log (Health Check)';
    protected int | string | array $columnSpan = 'full';
    protected static ?int $sort = 6;

    public static function canView(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(
                AutomationLog::query()
                    ->with('automation')
                    ->latest()
                    ->limit(10) // Show last 10 logs
            )
            ->columns([
                Tables\Columns\TextColumn::make('automation.name')
                    ->label(__('Process Name')),
                Tables\Columns\TextColumn::make('status')
                    ->label(__('Status'))
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'success' => 'success',
                        'failed' => 'danger',
                        default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('message')
                    ->label(__('Message'))
                    ->limit(50)
                    ->tooltip(function (Tables\Columns\TextColumn $column): ?string {
                        return $column->getState();
                    }),
                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('Ran At'))
                    ->dateTime()
                    ->sortable(),
            ]);
    }
}
