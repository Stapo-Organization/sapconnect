<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SupplierResource\Pages;
use App\Models\Supplier;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Forms\Components\Section;

class SupplierResource extends Resource
{
    protected static ?string $model = Supplier::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-storefront';
    protected static ?string $navigationGroup = 'Supply Chain';
    protected static ?string $modelLabel = 'Supplier';
    protected static ?string $pluralModelLabel = 'Suppliers';

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
                    ])->columns(3),

                Section::make('Performance & Contracts (Manual)')
                    ->schema([
                        Forms\Components\TextInput::make('target_amount')
                            ->numeric()
                            ->prefix('SAR'),
                        Forms\Components\Select::make('contract_ref')
                            ->label('Contract Reference')
                            ->searchable(), // If it's a string, we text input, but spec says "رقم مرجعي للعقد أو رابط للأرشفة"
                        Forms\Components\DatePicker::make('start_date'),
                        Forms\Components\DatePicker::make('end_date'),
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
                            ->prefix('SAR'),
                        Forms\Components\TextInput::make('rebates_bonuses')
                            ->numeric()
                            ->prefix('SAR'),
                        Forms\Components\Textarea::make('performance_notes')
                            ->columnSpanFull(),
                    ])->columns(3),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('sap_code')->searchable(),
                Tables\Columns\TextColumn::make('name')->searchable(),
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
                //
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
