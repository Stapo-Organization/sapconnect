<?php

namespace App\Filament\Widgets;

use App\Models\ProductIntelligence;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

/**
 * Good products that ran out (stockout-corrected). These should be RE-ORDERED, never
 * cleared — they are losing real sales while out of stock.
 */
class ZooboxiReorderWidget extends BaseWidget
{
    protected static ?string $heading = 'منتجات تخسر مبيعات بسبب الانقطاع — إعادة طلب (لا تصريف)';
    protected int|string|array $columnSpan = 'full';
    protected static bool $isDiscovered = false;

    public function table(Table $table): Table
    {
        return $table
            ->query(
                ProductIntelligence::query()
                    ->where('warehouse_code', '')
                    ->whereIn('health_status', ['starved', 'stockout'])
                    ->orderByDesc('lost_sales_monthly')
            )
            ->columns([
                Tables\Columns\TextColumn::make('lost_sales_monthly')
                    ->label('مبيعات مفقودة/شهر')->numeric(0)->sortable()->weight('bold')->color('danger'),
                Tables\Columns\TextColumn::make('item_code')->label('الكود')->searchable(),
                Tables\Columns\TextColumn::make('product.zb_name_ar')->label('المنتج')->wrap()->limit(45)->searchable(),
                Tables\Columns\TextColumn::make('health_status')->label('الحالة')->badge()
                    ->formatStateUsing(fn ($state) => $state === 'starved' ? 'مقطوع متكرّر' : 'نافد الآن')
                    ->color('warning'),
                Tables\Columns\TextColumn::make('v_true')->label('الطلب الحقيقي/يوم')->numeric(1)->sortable(),
                Tables\Columns\TextColumn::make('in_stock_rate')->label('نسبة التوفّر')
                    ->formatStateUsing(fn ($state) => round(((float) $state) * 100) . '%'),
                Tables\Columns\TextColumn::make('current_stock')->label('المخزون الحالي')->numeric(0),
                Tables\Columns\TextColumn::make('abc_class')->label('ABC')->badge(),
            ])
            ->defaultPaginationPageOption(10)
            ->paginated([10, 25, 50]);
    }
}
