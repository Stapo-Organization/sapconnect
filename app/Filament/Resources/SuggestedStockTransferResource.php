<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SuggestedStockTransferResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\SuggestedStockTransfer;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Actions\Action;
use Filament\Tables\Actions\BulkAction;
use App\Models\StockTransfer;

class SuggestedStockTransferResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = SuggestedStockTransfer::class;

    protected static ?string $navigationIcon = 'heroicon-o-light-bulb';
    protected static ?int $navigationSort = 2;

    public static function getNavigationLabel(): string { return __('Smart Stock Distribution'); }
    public static function getModelLabel(): string { return __('Transfer Suggestion'); }
    public static function getPluralModelLabel(): string { return __('Smart Stock Distribution'); }
    public static function getNavigationGroup(): ?string { return __('Retail'); }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('item_code')
                    ->label('المنتج')
                    ->searchable()
                    ->sortable()
                    ->description(fn (SuggestedStockTransfer $record): string => $record->product?->item_name ?? 'بدون وصف'),
                
                Tables\Columns\TextColumn::make('source_warehouse')
                    ->label('المنبع (المصدر)')
                    ->badge()
                    ->color('danger')
                    ->description(fn (SuggestedStockTransfer $record): string => "المخزون: " . (float)$record->source_stock . " | السحب اليومي: " . (float)$record->source_ads)
                    ->searchable(),
                
                Tables\Columns\TextColumn::make('target_warehouse')
                    ->label('الوجهة (الهدف)')
                    ->badge()
                    ->color('success')
                    ->description(fn (SuggestedStockTransfer $record): string => "المخزون: " . (float)$record->target_stock . " | السحب اليومي: " . (float)$record->target_ads)
                    ->searchable(),
                    
                Tables\Columns\TextColumn::make('ordered_qty')
                    ->label('بالطريق (Ordered)')
                    ->getStateUsing(function ($record) {
                        return \App\Models\WarehouseItemStock::where('item_code', $record->item_code)
                            ->where('warehouse_code', $record->target_warehouse)
                            ->value('ordered') ?? 0;
                    })
                    ->badge()
                    ->color('info')
                    ->icon('heroicon-m-clock'),

                Tables\Columns\TextColumn::make('transfer_type')
                    ->label('نوع التوزيع')
                    ->badge()
                    ->color(fn (SuggestedStockTransfer $record): string => 
                        str_contains(strtolower($record->sourceWarehouse?->warehouse_name ?? ''), 'store') ? 'warning' : 'info'
                    )
                    ->state(fn (SuggestedStockTransfer $record): string => 
                        str_contains(strtolower($record->sourceWarehouse?->warehouse_name ?? ''), 'store') ? 'عرضي' : 'مركزي'
                    ),

                Tables\Columns\TextColumn::make('suggested_quantity')
                    ->label('الكمية المقترحة')
                    ->numeric()
                    ->sortable()
                    ->weight('bold'),
                    
                Tables\Columns\TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'pending' => 'warning',
                        'approved' => 'success',
                        'dismissed' => 'danger',
                        default => 'gray',
                    }),
                    
                Tables\Columns\TextColumn::make('created_at')
                    ->label('تاريخ الفحص')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('suggested_quantity', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label('حالة الاقتراح')
                    ->options([
                        'pending' => 'قيد الانتظار',
                        'approved' => 'مُعتمد',
                        'dismissed' => 'مستبعد',
                    ])
                    ->default('pending'),
                
                Tables\Filters\SelectFilter::make('source_warehouse')
                    ->label('المنبع (المصدر)')
                    ->options(fn () => \App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code')->toArray())
                    ->searchable(),
                    
                Tables\Filters\SelectFilter::make('target_warehouse')
                    ->label('الوجهة (الهدف)')
                    ->options(fn () => \App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code')->toArray())
                    ->searchable(),
                    
                Tables\Filters\SelectFilter::make('transfer_type')
                    ->label('نوع التوزيع')
                    ->options([
                        'central' => 'مركزي (Central)',
                        'cross' => 'عرضي (Cross-Docking)'
                    ])
                    ->query(function ($query, array $data) {
                        if ($data['value'] === 'central') {
                            $query->whereHas('sourceWarehouse', function ($q) {
                                $q->where('warehouse_name', 'not like', '%Store%')
                                  ->where('warehouse_name', 'not like', '%ShipGo%');
                            });
                        } elseif ($data['value'] === 'cross') {
                            $query->whereHas('sourceWarehouse', function ($q) {
                                $q->where('warehouse_name', 'like', '%Store%');
                            });
                        }
                    }),
            ])
            ->actions([
                Action::make('approve')
                    ->label('اعتماد النقل')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (SuggestedStockTransfer $record) => $record->status === 'pending' && !auth()->user()?->hasRole('Stakeholder'))
                    ->form([
                        Forms\Components\TextInput::make('approved_quantity')
                            ->label('الكمية النهائية للنقل')
                            ->numeric()
                            ->default(fn (SuggestedStockTransfer $record) => $record->suggested_quantity)
                            ->required()
                            ->maxValue(fn (SuggestedStockTransfer $record) => $record->source_stock),
                    ])
                    ->action(function (SuggestedStockTransfer $record, array $data) {
                        // Create local stock transfer
                        $transfer = StockTransfer::create([
                            'from_warehouse' => $record->source_warehouse,
                            'to_warehouse' => $record->target_warehouse,
                            'doc_date' => now()->format('Y-m-d'),
                            'creation_date' => now(),
                            'internal_status' => StockTransfer::STATUS_NEW ?? 'New',
                            'document_status' => 'bost_Open',
                            'doc_num' => 'REQ-AI-' . time() . rand(10, 99),
                        ]);

                        $transfer->lines()->create([
                            'item_code' => $record->item_code,
                            'quantity' => $data['approved_quantity'],
                            'from_warehouse_code' => $record->source_warehouse,
                            'warehouse_code' => $record->target_warehouse,
                        ]);

                        $record->update([
                            'status' => 'approved',
                            'suggested_quantity' => $data['approved_quantity'] // update to what user actually approved
                        ]);
                    }),
                    
                Action::make('dismiss')
                    ->label('تجاهل')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->visible(fn (SuggestedStockTransfer $record) => $record->status === 'pending' && !auth()->user()?->hasRole('Stakeholder'))
                    ->action(fn (SuggestedStockTransfer $record) => $record->update(['status' => 'dismissed'])),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    BulkAction::make('bulk_approve')
                        ->label('اعتماد ودمج جماعي')
                        ->icon('heroicon-o-truck')
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(function (\Illuminate\Database\Eloquent\Collection $records) {
                            $grouped = $records->where('status', 'pending')->groupBy(function ($item) {
                                return $item->source_warehouse . '|' . $item->target_warehouse;
                            });

                            foreach ($grouped as $key => $items) {
                                $first = $items->first();
                                $transfer = StockTransfer::create([
                                    'from_warehouse' => $first->source_warehouse,
                                    'to_warehouse' => $first->target_warehouse,
                                    'doc_date' => now()->format('Y-m-d'),
                                    'creation_date' => now(),
                                    'internal_status' => StockTransfer::STATUS_NEW ?? 'New',
                                    'document_status' => 'bost_Open',
                                    'doc_num' => 'REQ-AI-' . time() . rand(100, 999),
                                ]);

                                foreach ($items as $item) {
                                    $transfer->lines()->create([
                                        'item_code' => $item->item_code,
                                        'quantity' => $item->suggested_quantity,
                                        'from_warehouse_code' => $item->source_warehouse,
                                        'warehouse_code' => $item->target_warehouse,
                                    ]);
                                    $item->update(['status' => 'approved']);
                                }
                            }
                        })
                        ->deselectRecordsAfterCompletion(),
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSuggestedStockTransfers::route('/'),
        ];
    }
}
