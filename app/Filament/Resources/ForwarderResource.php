<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ForwarderResource\Pages;
use App\Models\Forwarder;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class ForwarderResource extends Resource
{
    protected static ?string $model = Forwarder::class;

    protected static ?string $navigationIcon = 'heroicon-o-paper-airplane';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getModelLabel(): string { return __('Forwarder'); }
    public static function getPluralModelLabel(): string { return __('Forwarders'); }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Forwarder Information')
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255)
                            ->label('Company Name'),
                        Forms\Components\TextInput::make('contact_person')
                            ->maxLength(255)
                            ->label('Contact Person'),
                        Forms\Components\TextInput::make('contact_email')
                            ->email()
                            ->maxLength(255)
                            ->label('Email'),
                        Forms\Components\TextInput::make('contact_phone')
                            ->tel()
                            ->maxLength(255)
                            ->label('Phone'),
                        Forms\Components\Textarea::make('address')
                            ->columnSpanFull(),
                        Forms\Components\Toggle::make('is_active')
                            ->default(true)
                            ->label('Active'),
                    ])->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('contact_person')
                    ->searchable(),
                Tables\Columns\TextColumn::make('contact_email')
                    ->searchable(),
                Tables\Columns\TextColumn::make('contact_phone'),
                Tables\Columns\IconColumn::make('is_active')
                    ->boolean()
                    ->sortable(),
                Tables\Columns\TextColumn::make('shipments_count')
                    ->counts('shipments')
                    ->label('Shipments')
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label('Active Status'),
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
            'index' => Pages\ListForwarders::route('/'),
            'create' => Pages\CreateForwarder::route('/create'),
            'edit' => Pages\EditForwarder::route('/{record}/edit'),
        ];
    }
}
