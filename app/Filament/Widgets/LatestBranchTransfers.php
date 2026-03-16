<?php

namespace App\Filament\Widgets;

use App\Models\StockTransfer;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Illuminate\Database\Eloquent\Builder;

class LatestBranchTransfers extends BaseWidget
{
    protected static ?int $sort = 2;
    protected int | string | array $columnSpan = 'full';

    public static function canView(): bool
    {
        return auth()->user()->hasRole('Branch Manager');
    }

    protected function getTableHeading(): string|null
    {
        return __('أحدث التحويلات');
    }

    public function table(Table $table): Table
    {
        $user = auth()->user();
        $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
        $codes = array_filter($codes ?: []);

        return $table
            ->query(
                StockTransfer::query()
                    ->when(!empty($codes), function (Builder $query) use ($codes) {
                        $query->where(function ($q) use ($codes) {
                            $q->whereIn('from_warehouse', $codes)
                              ->orWhereIn('to_warehouse', $codes);
                        });
                    })
                    ->latest()
                    ->limit(10)
            )
            ->columns([
                Tables\Columns\TextColumn::make('doc_num')->label(__('Doc Num'))->searchable(),
                Tables\Columns\TextColumn::make('from_warehouse')->label(__('From')),
                Tables\Columns\TextColumn::make('to_warehouse')->label(__('To')),
                Tables\Columns\TextColumn::make('created_at')->label(__('Date'))->date()->sortable(),
                Tables\Columns\TextColumn::make('internal_status')
                    ->label(__('Internal Status'))
                    ->badge()
                    ->colors([
                        'gray' => StockTransfer::STATUS_NEW,
                        'warning' => StockTransfer::STATUS_SHIPPED,
                        'info' => StockTransfer::STATUS_RECEIVED,
                        'success' => StockTransfer::STATUS_COMPLETED,
                    ]),
            ])
            ->actions([
                Tables\Actions\Action::make('manage')
                    ->label(__('Manage'))
                    ->icon('heroicon-m-pencil-square')
                    ->url(fn (StockTransfer $record): string => \App\Filament\Resources\StockTransferResource::getUrl('edit', ['record' => $record])),
            ])
            ->paginated(false);
    }
}
