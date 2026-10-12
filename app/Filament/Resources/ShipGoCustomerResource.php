<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ShipGoCustomerResource\Pages;
use App\Models\ShipGoCustomer;
use Filament\Forms;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * ShipGo → ShipGo Customers.
 *
 * Read-only list of the ShipGo SAP company (SHIPGO_LIVE_V1) customers, mirrored
 * locally by `shipgo:sync-customers`, with a per-customer account statement PDF.
 * Nothing on this screen writes to SAP.
 */
class ShipGoCustomerResource extends Resource
{
    protected static ?string $model = ShipGoCustomer::class;

    protected static ?string $navigationIcon = 'heroicon-o-truck';
    protected static ?int $navigationSort = 1;
    protected static ?string $recordTitleAttribute = 'card_name';

    public static function getNavigationGroup(): ?string { return __('ShipGo'); }
    public static function getNavigationLabel(): string { return __('ShipGo Customers'); }
    public static function getModelLabel(): string { return __('ShipGo Customer'); }
    public static function getPluralModelLabel(): string { return __('ShipGo Customers'); }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Finance', 'Stakeholder', 'Operator', 'Accountant']);
    }

    public static function shouldRegisterNavigation(): bool { return static::canViewAny(); }

    // Mirror only — never created/edited/deleted from the panel.
    public static function canCreate(): bool { return false; }
    public static function canEdit($record): bool { return false; }
    public static function canDelete($record): bool { return false; }
    public static function canDeleteAny(): bool { return false; }

    public static function form(Forms\Form $form): Forms\Form
    {
        return $form->schema([]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('card_name')
            ->columns([
                Tables\Columns\TextColumn::make('card_code')
                    ->label(__('Card Code'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('card_name')
                    ->label(__('Card Name'))
                    ->searchable()
                    ->sortable()
                    ->wrap()
                    ->description(fn (ShipGoCustomer $r) => $r->card_foreign_name),
                Tables\Columns\TextColumn::make('cellular')
                    ->label(__('Phone'))
                    ->searchable(['cellular', 'phone1'])
                    ->getStateUsing(fn (ShipGoCustomer $r) => $r->cellular ?: $r->phone1)
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('city')
                    ->label(__('City'))
                    ->searchable()
                    ->toggleable()
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('federal_tax_id')
                    ->label(__('VAT Number'))
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true)
                    ->placeholder('-'),
                Tables\Columns\TextColumn::make('current_account_balance')
                    ->label(__('Account Balance'))
                    ->numeric(2)
                    ->sortable()
                    ->alignEnd()
                    ->color(fn ($state) => $state > 0 ? 'danger' : ($state < 0 ? 'success' : 'gray'))
                    ->description(fn (ShipGoCustomer $r) => $r->currency ?: 'SAR', position: 'above'),
                Tables\Columns\TextColumn::make('credit_limit')
                    ->label(__('Credit Limit'))
                    ->numeric(2)
                    ->sortable()
                    ->alignEnd()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\IconColumn::make('valid')
                    ->label(__('Active'))
                    ->boolean()
                    ->toggleable(),
                Tables\Columns\IconColumn::make('frozen')
                    ->label(__('Frozen'))
                    ->boolean()
                    ->trueColor('danger')
                    ->falseColor('gray')
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('synced_at')
                    ->label(__('Last Sync'))
                    ->since()
                    ->sortable()
                    ->toggleable(),
            ])
            ->filters([
                Tables\Filters\Filter::make('with_balance')
                    ->label(__('With outstanding balance'))
                    ->query(fn (Builder $q) => $q->where('current_account_balance', '!=', 0)),
                Tables\Filters\TernaryFilter::make('valid')->label(__('Active')),
                Tables\Filters\TernaryFilter::make('frozen')->label(__('Frozen')),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                static::statementAction(),
            ])
            ->bulkActions([])
            ->emptyStateHeading(__('No ShipGo customers yet'))
            ->emptyStateDescription(__('Run the sync to pull customers from SAP.'));
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Infolists\Components\Section::make(__('Customer'))
                ->columns(3)
                ->schema([
                    Infolists\Components\TextEntry::make('card_code')->label(__('Card Code'))->copyable()->weight('bold'),
                    Infolists\Components\TextEntry::make('card_name')->label(__('Card Name'))->columnSpan(2),
                    Infolists\Components\TextEntry::make('card_foreign_name')->label(__('Foreign Name'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('contact_person')->label(__('Contact Person'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('federal_tax_id')->label(__('VAT Number'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('cellular')->label(__('Cellular'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('phone1')->label(__('Phone 1'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('email_address')->label(__('Email Address'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('city')->label(__('City'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('country')->label(__('Country'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('address')->label(__('Address'))->placeholder('-'),
                ]),
            Infolists\Components\Section::make(__('Account'))
                ->columns(3)
                ->schema([
                    Infolists\Components\TextEntry::make('current_account_balance')
                        ->label(__('Account Balance'))
                        ->numeric(2)
                        ->suffix(fn (ShipGoCustomer $r) => ' ' . ($r->currency ?: 'SAR'))
                        ->color(fn ($state) => $state > 0 ? 'danger' : ($state < 0 ? 'success' : 'gray'))
                        ->weight('bold'),
                    Infolists\Components\TextEntry::make('open_orders_balance')->label(__('Open Orders'))->numeric(2),
                    Infolists\Components\TextEntry::make('open_delivery_notes_balance')->label(__('Open Deliveries'))->numeric(2),
                    Infolists\Components\TextEntry::make('credit_limit')->label(__('Credit Limit'))->numeric(2),
                    Infolists\Components\TextEntry::make('pay_terms_grp_code')->label(__('Payment Terms Group'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('group_code')->label(__('BP Group'))->placeholder('-'),
                    Infolists\Components\IconEntry::make('valid')->label(__('Active'))->boolean(),
                    Infolists\Components\IconEntry::make('frozen')->label(__('Frozen'))->boolean()->trueColor('danger')->falseColor('gray'),
                    Infolists\Components\TextEntry::make('synced_at')->label(__('Last Sync'))->dateTime('Y-m-d H:i')->placeholder('-'),
                    Infolists\Components\TextEntry::make('sap_create_date')->label(__('Created in SAP'))->date()->placeholder('-'),
                    Infolists\Components\TextEntry::make('sap_update_date')->label(__('Updated in SAP'))->date()->placeholder('-'),
                ]),
        ]);
    }

    /**
     * "Account statement (PDF)" — asks for the period then opens the PDF in a
     * new tab. Used as a table row action and as a header action on the view page.
     */
    public static function statementAction(): Tables\Actions\Action
    {
        return static::configureStatementAction(Tables\Actions\Action::make('statement'));
    }

    public static function headerStatementAction(): \Filament\Actions\Action
    {
        return static::configureStatementAction(\Filament\Actions\Action::make('statement'));
    }

    protected static function configureStatementAction($action)
    {
        return $action
            ->label(__('Account Statement (PDF)'))
            ->icon('heroicon-o-document-arrow-down')
            ->color('primary')
            ->modalHeading(__('Account Statement'))
            ->modalSubmitActionLabel(__('Generate PDF'))
            ->form([
                Forms\Components\DatePicker::make('from')
                    ->label(__('From'))
                    ->default(now()->startOfYear())
                    ->required()
                    ->native(false),
                Forms\Components\DatePicker::make('to')
                    ->label(__('To'))
                    ->default(now())
                    ->required()
                    ->native(false)
                    ->afterOrEqual('from'),
            ])
            ->action(function (array $data, $record, $livewire) {
                $url = route('shipgo.customers.statement', [
                    'cardCode' => $record->card_code,
                    'from'     => $data['from'],
                    'to'       => $data['to'],
                ]);
                $livewire->js('window.open(' . json_encode($url) . ", '_blank')");
            });
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListShipGoCustomers::route('/'),
            'view'  => Pages\ViewShipGoCustomer::route('/{record}'),
        ];
    }
}
