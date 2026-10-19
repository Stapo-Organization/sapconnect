<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ShipGoInvoiceResource\Pages;
use App\Models\ShipGoInvoice;
use Filament\Forms;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * ShipGo → ShipGo Invoices: read-only list of the ShipGo SAP company's A/R
 * invoices (mirrored headers) with a ZATCA tax-invoice PDF per invoice.
 * Nothing here writes to SAP.
 */
class ShipGoInvoiceResource extends Resource
{
    protected static ?string $model = ShipGoInvoice::class;

    protected static ?string $navigationIcon = 'heroicon-o-document-text';
    protected static ?int $navigationSort = 2;
    protected static ?string $recordTitleAttribute = 'doc_num';

    public static function getNavigationGroup(): ?string { return __('ShipGo'); }
    public static function getNavigationLabel(): string { return __('ShipGo Invoices'); }
    public static function getModelLabel(): string { return __('ShipGo Invoice'); }
    public static function getPluralModelLabel(): string { return __('ShipGo Invoices'); }

    /** Company hooks — overridden by MuntajatInvoiceResource. */
    public static function sapService(): \App\Services\ShipGo\ShipGoSapService
    {
        return app(\App\Services\ShipGo\ShipGoSapService::class);
    }

    public static function pdfRouteName(): string
    {
        return 'shipgo.invoices.pdf';
    }

    /** @return class-string<\Illuminate\Database\Eloquent\Model> */
    public static function customerModel(): string
    {
        return \App\Models\ShipGoCustomer::class;
    }

    public static function canViewAny(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Finance', 'Stakeholder', 'Operator', 'Accountant']);
    }

    public static function shouldRegisterNavigation(): bool { return static::canViewAny(); }
    public static function canCreate(): bool { return false; }
    public static function canEdit($record): bool { return false; }
    public static function canDelete($record): bool { return false; }
    public static function canDeleteAny(): bool { return false; }

    public static function form(Forms\Form $form): Forms\Form
    {
        return $form->schema([]);
    }

    public static function pdfUrl($record): string
    {
        return route(static::pdfRouteName(), ['docEntry' => $record->doc_entry]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('doc_date', 'desc')
            ->columns([
                Tables\Columns\TextColumn::make('doc_num')
                    ->label(__('Invoice No.'))
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('doc_date')
                    ->label(__('Date'))
                    ->date('Y-m-d')
                    ->sortable(),
                Tables\Columns\TextColumn::make('card_name')
                    ->label(__('Customer'))
                    ->searchable(['card_name', 'card_code'])
                    ->description(fn ($record) => $record->card_code)
                    ->wrap(),
                Tables\Columns\TextColumn::make('doc_total')
                    ->label(__('Total incl. VAT'))
                    ->numeric(2)
                    ->sortable()
                    ->alignEnd()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('vat_sum')
                    ->label(__('VAT'))
                    ->numeric(2)
                    ->alignEnd()
                    ->toggleable(),
                Tables\Columns\TextColumn::make('balance')
                    ->label(__('Balance'))
                    ->state(fn ($record) => $record->cancelled ? 0 : $record->balance)
                    ->numeric(2)
                    ->alignEnd()
                    ->color(fn ($state) => $state > 0 ? 'danger' : 'gray'),
                Tables\Columns\TextColumn::make('state')
                    ->label(__('Status'))
                    ->badge()
                    ->formatStateUsing(fn ($state) => ['open' => __('Unpaid'), 'paid' => __('Paid'), 'cancelled' => __('Cancelled')][$state] ?? $state)
                    ->color(fn ($state) => ['open' => 'warning', 'paid' => 'success', 'cancelled' => 'danger'][$state] ?? 'gray'),
                Tables\Columns\IconColumn::make('zatca_reported')
                    ->label(__('ZATCA'))
                    ->boolean()
                    ->tooltip(fn ($record) => $record->zatca_reported ? __('Cleared by ZATCA') . ' ' . optional($record->zatca_reported_at)->format('Y-m-d H:i') : __('Not reported to ZATCA')),
                Tables\Columns\TextColumn::make('doc_due_date')
                    ->label(__('Due date'))
                    ->date('Y-m-d')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('num_at_card')
                    ->label(__('Customer ref.'))
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('card_code')
                    ->label(__('Customer'))
                    ->searchable()
                    ->getSearchResultsUsing(fn (string $search) => static::customerModel()::query()
                        ->where(fn ($q) => $q->where('card_name', 'like', "%{$search}%")->orWhere('card_code', 'like', "%{$search}%"))
                        ->limit(50)->get()->mapWithKeys(fn ($c) => [$c->card_code => "{$c->card_code} — {$c->card_name}"])->all())
                    ->getOptionLabelUsing(fn ($value) => ($c = static::customerModel()::where('card_code', $value)->first()) ? "{$c->card_code} — {$c->card_name}" : $value),
                Tables\Filters\Filter::make('doc_date')
                    ->form([
                        Forms\Components\DatePicker::make('from')->label(__('From'))->native(false),
                        Forms\Components\DatePicker::make('until')->label(__('To'))->native(false),
                    ])
                    ->query(fn (Builder $q, array $data) => $q
                        ->when($data['from'] ?? null, fn ($q, $d) => $q->whereDate('doc_date', '>=', $d))
                        ->when($data['until'] ?? null, fn ($q, $d) => $q->whereDate('doc_date', '<=', $d)))
                    ->indicateUsing(fn (array $data) => array_filter([
                        ($data['from'] ?? null) ? __('From') . ' ' . $data['from'] : null,
                        ($data['until'] ?? null) ? __('To') . ' ' . $data['until'] : null,
                    ])),
                Tables\Filters\SelectFilter::make('payment')
                    ->label(__('Status'))
                    ->options(['open' => __('Unpaid'), 'paid' => __('Paid'), 'cancelled' => __('Cancelled')])
                    ->query(fn (Builder $q, array $data) => match ($data['value'] ?? null) {
                        'open'      => $q->where('cancelled', false)->where('status', 'open'),
                        'paid'      => $q->where('cancelled', false)->where('status', 'closed'),
                        'cancelled' => $q->where('cancelled', true),
                        default     => $q,
                    }),
                Tables\Filters\TernaryFilter::make('zatca_reported')->label(__('ZATCA')),
            ])
            ->actions([
                Tables\Actions\Action::make('pdf')
                    ->label(__('Invoice PDF'))
                    ->icon('heroicon-o-printer')
                    ->color('primary')
                    ->url(fn ($record) => static::pdfUrl($record))
                    ->openUrlInNewTab(),
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([])
            ->emptyStateHeading(__('No invoices yet'))
            ->emptyStateDescription(__('Run the sync to pull invoices from SAP.'));
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Infolists\Components\Section::make(__('Invoice'))
                ->columns(4)
                ->schema([
                    Infolists\Components\TextEntry::make('doc_num')->label(__('Invoice No.'))->weight('bold')->copyable(),
                    Infolists\Components\TextEntry::make('doc_date')->label(__('Date'))->date('Y-m-d')
                        ->suffix(fn ($record) => $record->doc_time ? '  ' . $record->doc_time : ''),
                    Infolists\Components\TextEntry::make('doc_due_date')->label(__('Due date'))->date('Y-m-d')->placeholder('-'),
                    Infolists\Components\TextEntry::make('state')->label(__('Status'))->badge()
                        ->formatStateUsing(fn ($state) => ['open' => __('Unpaid'), 'paid' => __('Paid'), 'cancelled' => __('Cancelled')][$state] ?? $state)
                        ->color(fn ($state) => ['open' => 'warning', 'paid' => 'success', 'cancelled' => 'danger'][$state] ?? 'gray'),
                    Infolists\Components\TextEntry::make('card_name')->label(__('Customer'))->columnSpan(2)
                        ->helperText(fn ($record) => $record->card_code),
                    Infolists\Components\TextEntry::make('buyer_vat')->label(__('VAT Number'))->placeholder('-'),
                    Infolists\Components\TextEntry::make('num_at_card')->label(__('Customer ref.'))->placeholder('-'),
                ]),
            Infolists\Components\Section::make(__('Amounts'))
                ->columns(4)
                ->schema([
                    Infolists\Components\TextEntry::make('doc_total')->label(__('Total incl. VAT'))->numeric(2)->weight('bold'),
                    Infolists\Components\TextEntry::make('vat_sum')->label(__('VAT'))->numeric(2),
                    Infolists\Components\TextEntry::make('paid_to_date')->label(__('Paid'))->numeric(2),
                    Infolists\Components\TextEntry::make('balance')->label(__('Balance'))->numeric(2)
                        ->color(fn ($state) => $state > 0 ? 'danger' : 'gray'),
                ]),
            Infolists\Components\Section::make(__('ZATCA'))
                ->columns(3)
                ->schema([
                    Infolists\Components\IconEntry::make('zatca_reported')->label(__('Reported to ZATCA'))->boolean(),
                    Infolists\Components\TextEntry::make('zatca_reported_at')->label(__('Reported at'))->dateTime('Y-m-d H:i')->placeholder('-'),
                    Infolists\Components\TextEntry::make('comments')->label(__('Notes'))->placeholder('-'),
                ]),
        ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListShipGoInvoices::route('/'),
            'view'  => Pages\ViewShipGoInvoice::route('/{record}'),
        ];
    }
}
