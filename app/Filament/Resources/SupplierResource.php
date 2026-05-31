<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SupplierResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Brand;
use App\Models\Supplier;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Forms\Components\Section;
use Illuminate\Database\Eloquent\Builder;

class SupplierResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = Supplier::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getModelLabel(): string { return __('Supplier'); }
    public static function getPluralModelLabel(): string { return __('Suppliers'); }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('SAP Master Data (Read Only)')
                    ->description('These fields are synced with SAP and cannot be modified here.')
                    ->schema([
                        Forms\Components\TextInput::make('sap_code')
                            ->required()
                            ->maxLength(255)
                            ->disabled(fn (string $operation): bool => $operation === 'edit'),
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255)
                            ->disabled(fn (string $operation): bool => $operation === 'edit'),
                        Forms\Components\TextInput::make('currency')
                            ->required()
                            ->default('SAR')
                            ->maxLength(255)
                            ->disabled(fn (string $operation): bool => $operation === 'edit'),
                        Forms\Components\TextInput::make('country')
                            ->label('Country')
                            ->disabled()
                            ->placeholder('From SAP'),
                        Forms\Components\TextInput::make('credit_limit')
                            ->numeric()
                            ->default(0.00)
                            ->disabled(),
                        Forms\Components\TextInput::make('open_po_value')
                            ->numeric()
                            ->default(0.00)
                            ->disabled(),
                        Forms\Components\TextInput::make('achieved_amount')
                            ->numeric()
                            ->default(0.00)
                            ->disabled(),
                        Forms\Components\TextInput::make('payment_terms_code')
                            ->label('SAP Payment Terms Code')
                            ->disabled()
                            ->placeholder('From SAP'),
                    ])->columns(2),

                Section::make('Classification & Admin (Manual)')
                    ->schema([
                        Forms\Components\Select::make('category')
                            ->options([
                                'Raw Materials' => 'Raw Materials',
                                'Services' => 'Services',
                                'Logistics' => 'Logistics',
                                'Other' => 'Other',
                            ])
                            ->searchable(),
                        Forms\Components\Select::make('user_id')
                            ->label('Account Manager')
                            ->options(User::all()->pluck('name', 'id'))
                            ->searchable(),
                        Forms\Components\TextInput::make('email')
                            ->email()
                            ->maxLength(255),
                        Forms\Components\Select::make('brands')
                            ->label('Brands')
                            ->multiple()
                            ->relationship('brands', 'name')
                            ->searchable()
                            ->preload()
                            ->helperText('Select the brands this supplier provides'),
                    ])->columns(3),

                Section::make('Performance & Contracts (Manual)')
                    ->schema([
                        Forms\Components\TextInput::make('target_amount')
                            ->numeric()
                            ->prefix(fn (callable $get) => $get('currency') ?? 'SAR'),
                        Forms\Components\TextInput::make('contract_ref')
                            ->label('Contract Reference')
                            ->maxLength(255)
                            ->placeholder('e.g., CNT-2026-001'),
                        Forms\Components\DatePicker::make('start_date'),
                        Forms\Components\DatePicker::make('end_date'),
                        Forms\Components\TextInput::make('contract_copy_url')
                            ->label('Contract Copy (URL/Path)')
                            ->url()
                            ->placeholder('https://drive.google.com/...')
                            ->suffixIcon('heroicon-o-link'),
                        Forms\Components\Textarea::make('renewal_conditions')
                            ->columnSpanFull(),
                    ])->columns(2),

                Section::make('Financial Agreements (Manual)')
                    ->schema([
                        Forms\Components\TextInput::make('agreed_discount')
                            ->numeric()
                            ->suffix('%'),
                        Forms\Components\TextInput::make('marketing_budget')
                            ->numeric()
                            ->prefix(fn (callable $get) => $get('currency') ?? 'SAR'),
                        Forms\Components\TextInput::make('rebates_bonuses')
                            ->numeric()
                            ->prefix(fn (callable $get) => $get('currency') ?? 'SAR'),
                        Forms\Components\Textarea::make('performance_notes')
                            ->columnSpanFull(),
                        Forms\Components\Textarea::make('general_comments')
                            ->label('General Comments')
                            ->columnSpanFull(),
                    ])->columns(3),

                Section::make('Financial Summary (Auto-Calculated)')
                    ->schema([
                        Forms\Components\Placeholder::make('amount_to_pay_display')
                            ->label('Amount To Pay (Pending Alerts)')
                            ->content(fn ($record) => $record ? number_format($record->amount_to_pay, 2) . ' ' . ($record->currency ?? 'SAR') : '—'),
                        Forms\Components\Placeholder::make('remaining_to_target_display')
                            ->label('Remaining to Achieve Target')
                            ->content(fn ($record) => $record ? number_format($record->remaining_to_target, 2) . ' ' . ($record->currency ?? 'SAR') : '—'),
                    ])->columns(2)
                    ->visibleOn('edit'),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('sap_code')->searchable(),
                Tables\Columns\TextColumn::make('name')->searchable(),
                Tables\Columns\ImageColumn::make('brands.image_url')
                    ->label('Brands')
                    ->circular()
                    ->stacked()
                    ->limit(5)
                    ->limitedRemainingText(),
                Tables\Columns\TextColumn::make('currency'),
                Tables\Columns\TextColumn::make('target_amount')
                    ->money(fn ($record) => $record->currency ?? 'SAR'),
                Tables\Columns\TextColumn::make('achieved_amount')
                    ->money(fn ($record) => $record->currency ?? 'SAR'),
                // Difference (Calculated) Custom column
                Tables\Columns\TextColumn::make('difference')
                    ->label('Difference')
                    ->getStateUsing(fn (Supplier $record): float => (float)$record->target_amount - (float)$record->achieved_amount)
                    ->money(fn ($record) => $record->currency ?? 'SAR')
                    ->color(fn (string $state): string => (float)$state >= 0 ? 'danger' : 'success')
                    ->tooltip('Target Amount - Achieved Amount'),
                Tables\Columns\TextColumn::make('category')->searchable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('category')
                    ->options([
                        'Raw Materials' => 'Raw Materials',
                        'Services' => 'Services',
                        'Logistics' => 'Logistics',
                        'Other' => 'Other',
                    ]),
                Tables\Filters\SelectFilter::make('user_id')
                    ->label('Account Manager')
                    ->relationship('accountManager', 'name'),
                Tables\Filters\Filter::make('contract_expiring')
                    ->label('Contract Expiring Soon (30 days)')
                    ->query(fn (Builder $query): Builder => $query->whereNotNull('end_date')->where('end_date', '<=', now()->addDays(30))),
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

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSuppliers::route('/'),
            'create' => Pages\CreateSupplier::route('/create'),
            'edit' => Pages\EditSupplier::route('/{record}/edit'),
        ];
    }
}
