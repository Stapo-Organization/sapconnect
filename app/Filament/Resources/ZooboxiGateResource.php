<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZooboxiGateResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Product;
use App\Services\Zooboxi\CatalogGateService;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;

/**
 * بوابة الكتالوج — the queue of production items NOT yet on the store, each
 * with the reason it is held. Fix the reason (picture, price, barcode) and the
 * next 15-minute run activates it; or block it so the gate never asks again.
 */
class ZooboxiGateResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = Product::class;

    protected static ?string $navigationIcon = 'heroicon-o-funnel';

    protected static ?string $slug = 'zooboxi-gate';

    protected static ?int $navigationSort = 2;

    public static function getNavigationLabel(): string
    {
        return __('بوابة الكتالوج');
    }

    public static function getModelLabel(): string
    {
        return __('Product');
    }

    public static function getPluralModelLabel(): string
    {
        return __('بوابة الكتالوج');
    }

    public static function getNavigationGroup(): ?string
    {
        return '🛒 Zooboxi Store';
    }

    public static function getNavigationBadge(): ?string
    {
        $n = Product::production()->where('zooboxi_active', false)->where('zooboxi_gate_status', 'held')->count();
        return $n > 0 ? (string) $n : null;
    }

    public static function getNavigationBadgeColor(): string|array|null
    {
        return 'warning';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->production()->with('brand');
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $q) => $q->where('zooboxi_active', false))
            ->defaultSort('zooboxi_gate_checked_at', 'desc')
            ->columns([
                Tables\Columns\ImageColumn::make('picture')
                    ->label(__('Image'))
                    ->state(fn (Product $r) => ($r->zb_resolved_images[0] ?? null) ?: ($r->zb_images[0] ?? null) ?: $r->image_url)
                    ->circular()->size(40),
                Tables\Columns\TextColumn::make('item_code')
                    ->label(__('Item Code'))->searchable()->copyable()->weight('bold'),
                Tables\Columns\TextColumn::make('item_name')
                    ->label(__('Name'))->searchable(['item_name', 'foreign_name', 'piece_barcode'])
                    ->description(fn (Product $r) => $r->foreign_name)->limit(60)->wrap(),
                Tables\Columns\TextColumn::make('brand.name')->label(__('Brand'))->toggleable(),
                Tables\Columns\TextColumn::make('piece_barcode')->label(__('Barcode'))->copyable()->toggleable(),
                Tables\Columns\TextColumn::make('zooboxi_gate_status')
                    ->label(__('الحالة'))->badge()
                    ->formatStateUsing(fn (?string $s) => match ($s) {
                        'held' => 'محجوز', 'blocked' => 'محظور', 'active' => 'مفعّل', default => 'بانتظار الفحص',
                    })
                    ->color(fn (?string $s) => match ($s) {
                        'held' => 'warning', 'blocked' => 'danger', 'active' => 'success', default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('zooboxi_gate_reasons')
                    ->label(__('السبب'))->badge()->separator(',')
                    ->formatStateUsing(fn ($state) => CatalogGateService::REASONS[$state] ?? $state)
                    ->color('gray'),
                Tables\Columns\TextColumn::make('express_stock')
                    ->label(__('إكسبريس'))->numeric()->alignEnd()
                    ->state(fn (Product $r) => (int) $r->warehouseStocks()->where('warehouse_code', '<>', config('services.zooboxi_gate.shipgo_warehouse', 'RUH003'))->sum('in_stock')),
                Tables\Columns\TextColumn::make('hub_stock')
                    ->label(config('services.zooboxi_gate.shipgo_warehouse', 'RUH003'))->numeric()->alignEnd()
                    ->state(fn (Product $r) => (int) $r->warehouseStocks()->where('warehouse_code', config('services.zooboxi_gate.shipgo_warehouse', 'RUH003'))->sum('in_stock')),
                Tables\Columns\TextColumn::make('zooboxi_gate_checked_at')
                    ->label(__('آخر فحص'))->since()->sortable(),
                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('Created'))->date()->sortable()->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('zooboxi_gate_status')
                    ->label(__('الحالة'))
                    ->options(['pending' => 'بانتظار الفحص', 'held' => 'محجوز', 'blocked' => 'محظور']),
                Tables\Filters\SelectFilter::make('reason')
                    ->label(__('السبب'))
                    ->options(CatalogGateService::REASONS)
                    ->query(fn (Builder $q, array $data) => filled($data['value'] ?? null)
                        ? $q->where('zooboxi_gate_reasons', 'like', '%"' . $data['value'] . '"%')
                        : $q),
                Tables\Filters\SelectFilter::make('items_group_code')
                    ->label(__('Brand'))->relationship('brand', 'name')->searchable()->preload(),
                Tables\Filters\Filter::make('has_stock')
                    ->label(__('In Stock'))
                    ->query(fn (Builder $q) => $q->whereHas('warehouseStocks', fn ($s) => $s->where('in_stock', '>', 0))),
            ])
            ->actions([
                Tables\Actions\Action::make('recheck')
                    ->label(__('تحقق الآن'))->icon('heroicon-o-arrow-path')
                    ->action(function (Product $record) {
                        $s = app(CatalogGateService::class)->run(itemCodes: [$record->item_code]);
                        $it = $s['items'][0] ?? null;
                        Notification::make()
                            ->title($it && $it['result'] === 'activated' ? 'تم التفعيل — سينزل في المتجر خلال ساعة' : 'ما زال محجوزًا')
                            ->body($it ? implode('، ', array_map(fn ($r) => CatalogGateService::REASONS[$r] ?? $r, $it['reasons'] ?? [])) : '')
                            ->{$it && $it['result'] === 'activated' ? 'success' : 'warning'}()->send();
                    }),
                Tables\Actions\Action::make('force')
                    ->label(__('تفعيل الآن'))->icon('heroicon-o-bolt')->color('success')
                    ->requiresConfirmation()
                    ->modalDescription('يتجاوز شرط المخزون فقط — السعر والباركود والصورة تبقى شروطًا.')
                    ->action(function (Product $record) {
                        $s = app(CatalogGateService::class)->run(itemCodes: [$record->item_code], force: true);
                        $it = $s['items'][0] ?? null;
                        Notification::make()
                            ->title($it && $it['result'] === 'activated' ? 'تم التفعيل' : 'لم يُفعَّل')
                            ->body($it ? implode('، ', array_map(fn ($r) => CatalogGateService::REASONS[$r] ?? $r, $it['reasons'] ?? [])) . ($it['error'] ?? '') : '')
                            ->{$it && $it['result'] === 'activated' ? 'success' : 'danger'}()->send();
                    }),
                Tables\Actions\Action::make('block')
                    ->label(__('حظر'))->icon('heroicon-o-no-symbol')->color('danger')
                    ->visible(fn (Product $r) => $r->zooboxi_gate_status !== 'blocked')
                    ->requiresConfirmation()
                    ->action(fn (Product $record) => app(CatalogGateService::class)->block($record, 'Filament')),
                Tables\Actions\Action::make('unblock')
                    ->label(__('رفع الحظر'))->icon('heroicon-o-check')->color('gray')
                    ->visible(fn (Product $r) => $r->zooboxi_gate_status === 'blocked')
                    ->action(fn (Product $record) => app(CatalogGateService::class)->unblock($record)),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\BulkAction::make('recheck')
                        ->label(__('تحقق الآن'))->icon('heroicon-o-arrow-path')
                        ->deselectRecordsAfterCompletion()
                        ->action(function (Collection $records) {
                            $s = app(CatalogGateService::class)->run(itemCodes: $records->pluck('item_code')->all());
                            Notification::make()->title("فُعّل {$s['activated']} · محجوز {$s['held']} · أخطاء {$s['errors']}")->success()->send();
                        }),
                    Tables\Actions\BulkAction::make('block')
                        ->label(__('حظر'))->icon('heroicon-o-no-symbol')->color('danger')
                        ->requiresConfirmation()->deselectRecordsAfterCompletion()
                        ->action(fn (Collection $records) => $records->each(fn ($r) => app(CatalogGateService::class)->block($r, 'Filament bulk'))),
                    Tables\Actions\BulkAction::make('unblock')
                        ->label(__('رفع الحظر'))->icon('heroicon-o-check')
                        ->deselectRecordsAfterCompletion()
                        ->action(fn (Collection $records) => $records->each(fn ($r) => app(CatalogGateService::class)->unblock($r))),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZooboxiGate::route('/'),
        ];
    }
}
