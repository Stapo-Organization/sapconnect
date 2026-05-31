<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PaymentAlertResource\Pages;
use App\Models\PaymentAlert;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class PaymentAlertResource extends Resource
{
    protected static ?string $model = PaymentAlert::class;

    protected static ?string $navigationIcon = 'heroicon-o-bell-alert';

    protected static ?string $navigationBadgeTooltip = 'Pending Payment Alerts';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getModelLabel(): string { return __('Payment Alert'); }
    public static function getPluralModelLabel(): string { return __('Payment Alerts'); }

    /**
     * Show count of pending alerts as navigation badge.
     */
    public static function getNavigationBadge(): ?string
    {
        $count = PaymentAlert::where('status', 'pending')->count();
        return $count > 0 ? (string) $count : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        $overdueCount = PaymentAlert::where('status', 'overdue')->count();
        return $overdueCount > 0 ? 'danger' : 'warning';
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Alert Details')
                    ->schema([
                        Forms\Components\Select::make('shipment_id')
                            ->relationship('shipment', 'id')
                            ->label('Shipment')
                            ->disabled(),
                        Forms\Components\Select::make('purchase_order_id')
                            ->relationship('purchaseOrder', 'id')
                            ->label('Purchase Order')
                            ->disabled(),
                        Forms\Components\TextInput::make('due_amount')
                            ->numeric()
                            ->disabled()
                            ->prefix(fn ($record) => $record?->purchaseOrder?->currency ?? 'SAR'),
                        Forms\Components\DatePicker::make('due_date')
                            ->disabled(),
                        Forms\Components\Select::make('status')
                            ->options([
                                'pending' => 'Pending',
                                'paid' => 'Paid',
                                'overdue' => 'Overdue',
                            ])
                            ->required(),
                        Forms\Components\Textarea::make('notes')
                            ->columnSpanFull(),
                    ])->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('Alert #')
                    ->sortable(),
                Tables\Columns\TextColumn::make('purchaseOrder.id')
                    ->label('PO')
                    ->searchable()
                    ->url(fn ($record) => $record->purchase_order_id ? "/admin/purchase-orders/{$record->purchase_order_id}/edit" : null),
                Tables\Columns\TextColumn::make('purchaseOrder.supplier.name')
                    ->label('Supplier')
                    ->searchable(),
                Tables\Columns\TextColumn::make('shipment.id')
                    ->label('Shipment'),
                Tables\Columns\TextColumn::make('paymentPolicyLine.condition')
                    ->label('Condition')
                    ->badge(),
                Tables\Columns\TextColumn::make('due_amount')
                    ->money(fn ($record) => $record->purchaseOrder?->currency ?? 'SAR')
                    ->sortable(),
                Tables\Columns\TextColumn::make('due_date')
                    ->date()
                    ->sortable()
                    ->color(fn ($record) => $record->isOverdue() ? 'danger' : null),
                Tables\Columns\BadgeColumn::make('status')
                    ->colors([
                        'warning' => 'pending',
                        'success' => 'paid',
                        'danger' => 'overdue',
                    ]),
                Tables\Columns\TextColumn::make('paid_at')
                    ->dateTime()
                    ->label('Paid At')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('due_date', 'asc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'paid' => 'Paid',
                        'overdue' => 'Overdue',
                    ]),
                Tables\Filters\Filter::make('overdue')
                    ->label('Overdue Only')
                    ->query(fn (Builder $query): Builder => $query->where('status', 'pending')->where('due_date', '<', now())),
            ])
            ->actions([
                Tables\Actions\Action::make('mark_paid')
                    ->label('Mark as Paid')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->visible(fn ($record) => $record->status !== 'paid')
                    ->requiresConfirmation()
                    ->modalHeading('Mark Payment as Paid')
                    ->modalDescription('Are you sure you want to mark this payment alert as paid?')
                    ->action(function (PaymentAlert $record) {
                        $record->markAsPaid(auth()->id());
                    }),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPaymentAlerts::route('/'),
            'edit' => Pages\EditPaymentAlert::route('/{record}/edit'),
        ];
    }
}
