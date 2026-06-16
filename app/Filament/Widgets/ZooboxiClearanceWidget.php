<?php

namespace App\Filament\Widgets;

use App\Models\ClearanceCampaign;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class ZooboxiClearanceWidget extends BaseWidget
{
    protected static ?string $heading = 'قائمة التصريف — مرتّبة بالأولوية (LPS)';
    protected int|string|array $columnSpan = 'full';
    protected static bool $isDiscovered = false;

    public function table(Table $table): Table
    {
        return $table
            ->query(
                ClearanceCampaign::query()
                    ->whereIn('status', ['suggested', 'active'])
                    ->orderByDesc('lps')
            )
            ->columns([
                Tables\Columns\TextColumn::make('lps')
                    ->label('الأولوية')->numeric(1)->sortable()->weight('bold')->color('danger'),
                Tables\Columns\TextColumn::make('item_code')->label('الكود')->searchable(),
                Tables\Columns\TextColumn::make('product.zb_name_ar')
                    ->label('المنتج')->wrap()->limit(45)->searchable(),
                Tables\Columns\TextColumn::make('reason')->label('السبب')->badge()
                    ->formatStateUsing(fn ($state) => match ($state) {
                        'never_sold' => 'لم يُبَع', 'dead' => 'راكد', 'overstock' => 'متكدّس', default => $state,
                    })
                    ->color(fn ($state) => match ($state) {
                        'never_sold' => 'danger', 'dead' => 'warning', default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('capital_tied_sar')->label('رأس المال المجمّد')->money('SAR')->sortable(),
                Tables\Columns\TextColumn::make('days_of_cover')->label('تغطية (يوم)')->numeric(0)->placeholder('—'),
                Tables\Columns\TextColumn::make('retail_price')->label('سعر التجزئة')->money('SAR'),
                Tables\Columns\TextColumn::make('floor_price')->label('أرضية السعر')->money('SAR')
                    ->tooltip('لا يُباع تحتها — تحمي سعر الجملة'),
                Tables\Columns\TextColumn::make('status')->label('الحالة')->badge(),
            ])
            ->defaultPaginationPageOption(10)
            ->paginated([10, 25, 50, 100]);
    }
}
