<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CustomerResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Customer;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Illuminate\Database\Eloquent\Builder;

class CustomerResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = Customer::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    public static function getNavigationLabel(): string
    {
        return __('Customers');
    }

    public static function getModelLabel(): string
    {
        return __('Customer');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Customers');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Master Data');
    }

    protected static ?int $navigationSort = 3;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('card_code')
                    ->label(__('Card Code'))
                    ->required()
                    ->maxLength(255),
                Forms\Components\TextInput::make('card_name')
                    ->label(__('Card Name'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('phone1')
                    ->label(__('Phone 1'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('contact_person')
                    ->label(__('Contact Person'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('vat_liable')
                    ->label(__('VAT Liable'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('federal_tax_id')
                    ->label(__('Federal Tax ID'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('cellular')
                    ->label(__('Cellular'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('email_address')
                    ->label(__('Email Address'))
                    ->email()
                    ->maxLength(255),
                Forms\Components\TextInput::make('city')
                    ->label(__('City'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('country')
                    ->label(__('Country'))
                    ->maxLength(255),
                Forms\Components\TextInput::make('u_portal_sync')
                    ->label(__('Portal Sync')),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('card_code')
                    ->label(__('Card Code'))
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('card_name')
                    ->label(__('Card Name'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('phone1')
                    ->label(__('Phone 1'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('cellular')
                    ->label(__('Cellular'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('email_address')
                    ->label(__('Email'))
                    ->searchable(),
                Tables\Columns\TextColumn::make('city')
                    ->label(__('City'))
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('u_portal_sync')
                    ->label(__('Portal Sync'))
                    ->badge(),
                Tables\Columns\TextColumn::make('update_date')
                    ->label(__('Last Update'))
                    ->date()
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('u_portal_sync')
                    ->label(__('Portal Sync'))
                    ->options(fn () => \App\Models\Customer::whereNotNull('u_portal_sync')->distinct()->pluck('u_portal_sync', 'u_portal_sync')->toArray()),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Section::make(__('Customer Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('card_code')->label(__('Card Code')),
                        Infolists\Components\TextEntry::make('card_name')->label(__('Card Name')),
                        Infolists\Components\TextEntry::make('card_type')->label(__('Card Type')),
                        Infolists\Components\TextEntry::make('phone1')->label(__('Phone 1')),
                        Infolists\Components\TextEntry::make('cellular')->label(__('Cellular')),
                        Infolists\Components\TextEntry::make('email_address')->label(__('Email')),
                        Infolists\Components\TextEntry::make('contact_person')->label(__('Contact Person')),
                    ])->columns(2),
                Infolists\Components\Section::make(__('Tax & Registration'))
                    ->schema([
                        Infolists\Components\TextEntry::make('vat_liable')->label(__('VAT Liable')),
                        Infolists\Components\TextEntry::make('federal_tax_id')->label(__('Federal Tax ID')),
                        Infolists\Components\TextEntry::make('company_registration_number')->label(__('CR Number')),
                    ])->columns(2),
                Infolists\Components\Section::make(__('Address Details'))
                    ->schema([
                        Infolists\Components\TextEntry::make('city')->label(__('City')),
                        Infolists\Components\TextEntry::make('county')->label(__('County')),
                        Infolists\Components\TextEntry::make('country')->label(__('Country')),
                        Infolists\Components\TextEntry::make('mail_city')->label(__('Mail City')),
                        Infolists\Components\TextEntry::make('mail_county')->label(__('Mail County')),
                        Infolists\Components\TextEntry::make('mail_country')->label(__('Mail Country')),
                        Infolists\Components\TextEntry::make('ship_to_default')->label(__('Ship To Default')),
                    ])->columns(2),
                Infolists\Components\Section::make(__('Sync Information'))
                    ->schema([
                        Infolists\Components\TextEntry::make('u_portal_sync')->label(__('Portal Sync')),
                        Infolists\Components\TextEntry::make('u_iban')->label(__('IBAN')),
                        Infolists\Components\TextEntry::make('create_date')->label(__('Create Date')),
                        Infolists\Components\TextEntry::make('create_time')->label(__('Create Time')),
                        Infolists\Components\TextEntry::make('update_date')->label(__('Update Date')),
                        Infolists\Components\TextEntry::make('update_time')->label(__('Update Time')),
                    ])->columns(2),
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
            'index' => Pages\ListCustomers::route('/'),
            'create' => Pages\CreateCustomer::route('/create'),
            'edit' => Pages\EditCustomer::route('/{record}/edit'),
        ];
    }
}
