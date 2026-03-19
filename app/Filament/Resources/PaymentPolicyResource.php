<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PaymentPolicyResource\Pages;
use App\Models\PaymentPolicy;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Closure;

class PaymentPolicyResource extends Resource
{
    protected static ?string $model = PaymentPolicy::class;

    protected static ?string $navigationIcon = 'heroicon-o-document-text';
    protected static ?string $navigationGroup = 'Supply Chain';
    protected static ?string $modelLabel = 'Payment Policy';
    protected static ?string $pluralModelLabel = 'Payment Policies';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Policy Details')
                    ->schema([
                        Forms\Components\Select::make('supplier_id')
                            ->relationship('supplier', 'name')
                            ->searchable()
                            ->preload()
                            ->required(),
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255)
                            ->placeholder('e.g., 30% Advance, 70% LC'),
                    ])->columns(2),

                Forms\Components\Section::make('Payment Lines (Must sum to 100%)')
                    ->schema([
                        Forms\Components\Repeater::make('lines')
                            ->relationship()
                            ->schema([
                                Forms\Components\TextInput::make('percentage')
                                    ->numeric()
                                    ->required()
                                    ->minValue(1)
                                    ->maxValue(100)
                                    ->suffix('%'),
                                Forms\Components\Select::make('condition')
                                    ->options([
                                        'on_shipment' => 'On Shipment (ETD)',
                                        'on_arrival' => 'On Arrival (ETA)',
                                        'on_clearance' => 'On Clearance',
                                        'invoice_date' => 'Invoice Date',
                                        'other' => 'Other',
                                    ])
                                    ->required(),
                                Forms\Components\TextInput::make('due_days')
                                    ->numeric()
                                    ->required()
                                    ->default(0)
                                    ->suffix('Days'),
                            ])
                            ->columns(3)
                            ->rule(function () {
                                return function (string $attribute, $value, Closure $fail) {
                                    if (empty($value)) return;
                                    
                                    $totalPercentage = collect($value)->sum('percentage');
                                    if ($totalPercentage != 100) {
                                        $fail("The total percentage of all payment lines must equal exactly 100%. Currently it is {$totalPercentage}%.");
                                    }
                                };
                            })
                            ->required()
                            ->minItems(1),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('supplier.name')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('name')
                    ->searchable(),
                Tables\Columns\TextColumn::make('lines_count')
                    ->counts('lines')
                    ->label('Installments'),
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('updated_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
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

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPaymentPolicies::route('/'),
            'create' => Pages\CreatePaymentPolicy::route('/create'),
            'edit' => Pages\EditPaymentPolicy::route('/{record}/edit'),
        ];
    }
}
