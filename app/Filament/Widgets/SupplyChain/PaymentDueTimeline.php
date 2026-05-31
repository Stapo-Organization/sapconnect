<?php

namespace App\Filament\Widgets\SupplyChain;

use App\Models\PaymentAlert;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class PaymentDueTimeline extends BaseWidget
{
    protected static ?string $heading = 'Upcoming Payment Due Dates';

    protected int | string | array $columnSpan = 'full';

    public function table(Table $table): Table
    {
        return $table
            ->query(
                PaymentAlert::query()
                    ->where('status', '!=', 'paid')
                    ->orderBy('due_date', 'asc')
                    ->limit(10)
            )
            ->columns([
                Tables\Columns\TextColumn::make('purchaseOrder.supplier.name')
                    ->label('Supplier')
                    ->searchable(),
                Tables\Columns\TextColumn::make('purchaseOrder.id')
                    ->label('PO #'),
                Tables\Columns\TextColumn::make('paymentPolicyLine.condition')
                    ->label('Condition')
                    ->badge(),
                Tables\Columns\TextColumn::make('due_amount')
                    ->money('SAR')
                    ->sortable(),
                Tables\Columns\TextColumn::make('due_date')
                    ->date()
                    ->sortable()
                    ->color(fn ($record) => $record->isOverdue() ? 'danger' : null),
                Tables\Columns\BadgeColumn::make('status')
                    ->colors([
                        'warning' => 'pending',
                        'danger' => 'overdue',
                    ]),
            ]);
    }
}
