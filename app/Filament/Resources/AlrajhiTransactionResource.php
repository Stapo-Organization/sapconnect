<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AlrajhiTransactionResource\Pages; 
use App\Models\AlrajhiTransaction;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Actions\Action;
use Illuminate\Support\Facades\Http;
use Filament\Notifications\Notification;
use Carbon\Carbon;
use Illuminate\Support\Str;

class AlrajhiTransactionResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    protected static ?string $model = AlrajhiTransaction::class;

    protected static ?string $navigationIcon = 'heroicon-o-banknotes';

    public static function getNavigationLabel(): string
    {
        return __('AlRajhi Transactions');
    }

    public static function getModelLabel(): string
    {
        return __('AlRajhi Transaction');
    }

    public static function getPluralModelLabel(): string
    {
        return __('AlRajhi Transactions');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Transaction Details'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('msg_reference')
                            ->label(__('Reference'))
                            ->columnSpanFull(),

                        Forms\Components\DateTimePicker::make('creation_date')
                            ->label(__('Creation Date')),

                        Forms\Components\TextInput::make('amount')
                            ->label(__('Amount'))
                            ->prefix(__('SAR')),

                        Forms\Components\Placeholder::make('status')
                            ->label(__('Status'))
                            ->content(fn($record) => new \Illuminate\Support\HtmlString(
                                match ($record?->status) {
                                    'incoming_payment_succeesfully_added' => '<span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">' . __('Success') . '</span>',
                                    'failed_to_add_incoming_payment' => '<span class="inline-flex items-center rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/10">' . __('Failed') . '</span>',
                                    default => '<span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">' . ($record?->status ?? '-') . '</span>',
                                }
                            )),
                    ]),

                Forms\Components\Section::make(__('Customer Information'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('transfer_customer_name')
                            ->label(__('Transfer Name')),

                        Forms\Components\TextInput::make('sap_customer_name')
                            ->label(__('SAP Name')),

                        Forms\Components\TextInput::make('sap_card_code')
                            ->label(__('SAP Code')),

                        Forms\Components\TextInput::make('customer_iban')
                            ->label(__('Customer IBAN')),

                        Forms\Components\TextInput::make('payment_iban')
                            ->label(__('Collection IBAN')),
                    ]),

                Forms\Components\Section::make(__('Invoices'))
                    ->schema([
                        Forms\Components\KeyValue::make('invoices')
                            ->label(__('Settled Invoices'))
                            ->formatStateUsing(function ($state) {
                                // Convert array of objects to simple key-value for display if needed
                                // Or better, use a Repeater if we want to show it nicely
                                // But KeyValue expects key => value.
                                // Let's use a Placeholder/View for this or JSON view.
                                return $state;
                            })
                            ->columnSpanFull()
                            ->hidden(), // Hide KeyValue, use JSON or Repeater? 

                        // Use a ViewField or just a Repeater in 'read' mode if we could
                        // For now, let's use the JSON viewer for raw invoices data, 
                        // or a repeater that maps the data.
                        Forms\Components\Repeater::make('invoices_list')
                            ->label(__('Invoices List'))
                            ->schema([
                                Forms\Components\TextInput::make('DocEntry')->label(__('Doc Entry')),
                                Forms\Components\TextInput::make('SumApplied')->label(__('Sum Applied')),
                            ])
                            ->formatStateUsing(fn($record) => $record?->invoices ?? []) // Map from 'invoices' attribute
                            ->dehydrated(false) // Don't save this field back
                            ->columnSpanFull(),
                    ]),

                Forms\Components\Section::make(__('Raw Data'))
                    ->collapsed()
                    ->schema([
                        Forms\Components\Textarea::make('raw_data')
                            ->formatStateUsing(fn($state) => json_encode($state, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE))
                            ->rows(10)
                            ->columnSpanFull(),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('creation_date')
                    ->dateTime()
                    ->sortable()
                    ->label(__('Date')),

                Tables\Columns\TextColumn::make('sap_card_code')
                    ->label(__('SAP Code'))
                    ->searchable(),

                Tables\Columns\TextColumn::make('transfer_customer_name')
                    ->label(__('Transfer Customer'))
                    ->searchable()
                    ->limit(30)
                    ->toggleable(),

                Tables\Columns\TextColumn::make('sap_customer_name')
                    ->label(__('SAP Customer'))
                    ->searchable()
                    ->limit(30)
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('amount')
                    ->label(__('Amount'))
                    ->money('SAR')
                    ->sortable(),

                Tables\Columns\TextColumn::make('customer_iban')
                    ->label(__('Customer IBAN'))
                    ->copyable()
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('invoices')
                    ->label(__('Settled Invoices'))
                    ->html()
                    ->formatStateUsing(function ($state) {
                        if (empty($state))
                            return '<span class="text-gray-400 text-xs">-</span>';

                        $invoices = $state;
                        // Decode if string
                        if (is_string($state)) {
                            $invoices = json_decode($state, true);
                            if (is_string($invoices)) {
                                $invoices = json_decode($invoices, true);
                            }
                        }

                        if (!is_array($invoices) || empty($invoices))
                            return '<span class="text-gray-400 text-xs">-</span>';

                        $formatted = [];
                        foreach ($invoices as $inv) {
                            if (!is_array($inv))
                                continue;

                            $doc = $inv['DocEntry'] ?? $inv['docEntry'] ?? $inv['doc_entry'] ?? 'N/A';
                            $sum = $inv['SumApplied'] ?? $inv['sumApplied'] ?? $inv['sum_applied'] ?? 0;

                            $formatted[] = sprintf(
                                '<div class="flex items-center gap-2 text-xs border-b border-gray-100 last:border-0 py-1">' .
                                '<span class="font-medium text-gray-600">' . __('Doc:') . '</span> <span class="font-bold text-primary-600">%s</span>' .
                                '<span class="text-gray-300">|</span>' .
                                '<span class="font-medium text-gray-600">' . __('Amt:') . '</span> <span class="font-bold text-success-600">%s</span>' .
                                '</div>',
                                $doc,
                                number_format((float) $sum, 2)
                            );
                        }
                        return '<div class="flex flex-col min-w-[150px]">' . implode('', $formatted) . '</div>';
                    })
                    ->toggleable(),

                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'incoming_payment_succeesfully_added' => 'success',
                        'failed_to_add_incoming_payment' => 'danger',
                        default => 'gray', // 'Collected' or others
                    })
                    ->formatStateUsing(fn(string $state): string => str($state)->replace('_', ' ')->title()),
            ])
            ->defaultSort('creation_date', 'desc')
            ->filters([
                Tables\Filters\Filter::make('creation_date')
                    ->form([
                        Forms\Components\DatePicker::make('created_from')->label(__('From Date')),
                        Forms\Components\DatePicker::make('created_until')->label(__('To Date')),
                    ])
                    ->query(function ($query, array $data) {
                        return $query
                            ->when(
                                $data['created_from'],
                                fn($query, $date) => $query->whereDate('creation_date', '>=', $date),
                            )
                            ->when(
                                $data['created_until'],
                                fn($query, $date) => $query->whereDate('creation_date', '<=', $date),
                            );
                    }),

                Tables\Filters\Filter::make('sap_card_code')
                    ->form([
                        Forms\Components\TextInput::make('sap_card_code_input')->label(__('Customer Code')),
                    ])
                    ->query(function ($query, array $data) {
                        return $query->when(
                            $data['sap_card_code_input'],
                            fn($query, $code) => $query->where('sap_card_code', 'like', "%{$code}%")
                        );
                    }),

                Tables\Filters\Filter::make('exclude_sap_card_code')
                    ->form([
                        Forms\Components\TextInput::make('code')
                            ->label(__('Exclude Customer Code'))
                            ->default('00000'),
                    ])
                    ->query(function ($query, array $data) {
                        return $query->when(
                            $data['code'],
                            fn($query, $code) => $query->where('sap_card_code', '!=', $code)
                        );
                    })
                    ->indicateUsing(function (array $data): ?string {
                        return $data['code'] ? "Excluding: {$data['code']}" : null;
                    }),

                Tables\Filters\SelectFilter::make('status')
                    ->label(__('Status'))
                    ->options([
                        'incoming_payment_succeesfully_added' => __('Success'),
                        'failed_to_add_incoming_payment' => __('Failed'),
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->headerActions([
                Action::make('fetch_data')
                    ->label(__('Fetch Data'))
                    ->icon('heroicon-o-arrow-path')
                    ->action(function () {
                        self::fetchData();
                    }),
            ])
            ->bulkActions([
                // Tables\Actions\DeleteBulkAction::make(),
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
            'index' => Pages\ListAlrajhiTransactions::route('/'),
            // 'create' => Pages\CreateAlrajhiTransaction::route('/create'),
            // 'edit' => Pages\EditAlrajhiTransaction::route('/{record}/edit'),
        ];
    }

    protected static function fetchData()
    {
        try {
            \Illuminate\Support\Facades\Artisan::call('sap:sync-alrajhi');
            $output = \Illuminate\Support\Facades\Artisan::output();
            
            Notification::make()
                ->title(__('Sync Command Executed'))
                ->body($output)
                ->success()
                ->send();
        } catch (\Exception $e) {
            Notification::make()
                ->title(__('Error running sync command'))
                ->body($e->getMessage())
                ->danger()
                ->send();
        }
    }
}