<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ProductRegistrationResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\ProductRegistration;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * SFDA product-registration board — replaces the manual registration tabs of the
 * Operations workbook. Standalone by design (see ProductRegistration / migration):
 * keyed by legacy item_code, product link is best-effort/nullable.
 */
class ProductRegistrationResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = ProductRegistration::class;

    protected static ?string $navigationIcon = 'heroicon-o-clipboard-document-check';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getNavigationLabel(): string { return __('SFDA Registration'); }
    public static function getModelLabel(): string { return __('Registration'); }
    public static function getPluralModelLabel(): string { return __('SFDA Registrations'); }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('المنتج / Product')
                ->schema([
                    Forms\Components\TextInput::make('item_code')
                        ->label('Item / Vendor Code')
                        ->required()
                        ->maxLength(255),
                    Forms\Components\TextInput::make('name_ar')
                        ->label('الاسم بالعربي')
                        ->maxLength(255),
                    Forms\Components\TextInput::make('item_name')
                        ->label('Item Name (EN)')
                        ->maxLength(255),
                    Forms\Components\TextInput::make('brand_code')
                        ->label('Brand Code')
                        ->maxLength(255),
                    Forms\Components\TextInput::make('range')
                        ->label('Range / Sub-brand')
                        ->maxLength(255),
                    Forms\Components\TextInput::make('vendor_code')
                        ->label('Vendor Code')
                        ->maxLength(255),
                ])->columns(3),

            Forms\Components\Section::make('التسجيل / Registration')
                ->schema([
                    Forms\Components\Select::make('status')
                        ->label('Status')
                        ->options(ProductRegistration::statusOptions())
                        ->default('new')
                        ->required(),
                    Forms\Components\Toggle::make('is_registered')
                        ->label('Registered?'),
                    Forms\Components\TextInput::make('reference_number')
                        ->label('Reference / Submission No.')
                        ->maxLength(255),
                    Forms\Components\TextInput::make('certificate_number')
                        ->label('Certificate No.')
                        ->maxLength(255),
                    Forms\Components\DatePicker::make('request_date')->label('Request Date'),
                    Forms\Components\DatePicker::make('received_date')->label('Received Date'),
                    Forms\Components\DatePicker::make('expiry_date')->label('Expiry Date'),
                ])->columns(3),

            Forms\Components\Section::make('ملاحظات / Notes')
                ->schema([
                    Forms\Components\Textarea::make('remarks')->label('Remarks')->columnSpanFull(),
                ])->collapsible()->collapsed(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('item_code')
                    ->label('Code')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('name_ar')
                    ->label('الاسم')
                    ->searchable()
                    ->limit(40)
                    ->wrap(),
                Tables\Columns\TextColumn::make('item_name')
                    ->label('Name (EN)')
                    ->searchable()
                    ->limit(30)
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('brand_code')
                    ->label('Brand')
                    ->searchable()
                    ->toggleable(),
                Tables\Columns\TextColumn::make('range')
                    ->label('Range')
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\BadgeColumn::make('status')
                    ->label('Status')
                    ->formatStateUsing(fn ($state) => ProductRegistration::statusOptions()[$state] ?? $state)
                    ->color(fn ($state) => ProductRegistration::statusColor($state)),
                Tables\Columns\TextColumn::make('certificate_number')
                    ->label('Certificate')
                    ->searchable()
                    ->limit(24)
                    ->toggleable(),
                Tables\Columns\IconColumn::make('is_registered')
                    ->label('Reg?')
                    ->boolean(),
                Tables\Columns\TextColumn::make('expiry_date')
                    ->label('Expiry')
                    ->date()
                    ->sortable(),
                Tables\Columns\TextColumn::make('expires_in')
                    ->label('Expires In')
                    ->badge()
                    ->getStateUsing(function (ProductRegistration $record): string {
                        if (!$record->expiry_date) return '—';
                        $days = (int) now()->startOfDay()->diffInDays($record->expiry_date, false);
                        if ($days < 0) return abs($days) . 'd ago';
                        if ($days === 0) return 'Today';
                        return $days . ' days';
                    })
                    ->color(function (ProductRegistration $record): string {
                        if (!$record->expiry_date) return 'gray';
                        if ($record->isExpired()) return 'danger';
                        if ($record->isExpiringSoon()) return 'warning';
                        return 'success';
                    }),
                Tables\Columns\IconColumn::make('product_id')
                    ->label('Linked')
                    ->getStateUsing(fn (ProductRegistration $record) => $record->product_id !== null)
                    ->boolean()
                    ->toggleable(),
            ])
            ->defaultSort('name_ar', 'asc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options(ProductRegistration::statusOptions())
                    ->multiple(),
                Tables\Filters\SelectFilter::make('brand_code')
                    ->options(fn () => ProductRegistration::query()
                        ->whereNotNull('brand_code')
                        ->distinct()
                        ->orderBy('brand_code')
                        ->pluck('brand_code', 'brand_code')
                        ->toArray())
                    ->searchable(),
                Tables\Filters\TernaryFilter::make('is_registered')
                    ->label('Registered'),
                Tables\Filters\Filter::make('expiring_soon')
                    ->label('Expiring within 90 days')
                    ->query(fn (Builder $query) => $query
                        ->whereNotNull('expiry_date')
                        ->whereBetween('expiry_date', [now(), now()->addDays(ProductRegistration::EXPIRING_SOON_DAYS)])),
                Tables\Filters\Filter::make('unmatched')
                    ->label('Unmatched SKU (no product)')
                    ->query(fn (Builder $query) => $query->whereNull('product_id')),
            ])
            ->actions([
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
            'index'  => Pages\ListProductRegistrations::route('/'),
            'create' => Pages\CreateProductRegistration::route('/create'),
            'edit'   => Pages\EditProductRegistration::route('/{record}/edit'),
        ];
    }
}
