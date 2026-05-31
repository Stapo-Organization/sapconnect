<?php

namespace App\Filament\Resources;

use App\Filament\Resources\StockTransferResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\StockTransfer;
use App\Models\StockTransferLine;
use App\Services\StockTransferService;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Filament\Notifications\Notification;

class StockTransferResource extends Resource
{
    use ReadOnlyStakeholder;
    protected static ?string $model = StockTransfer::class;

    protected static ?string $navigationIcon = 'heroicon-o-truck';

    public static function getNavigationLabel(): string
    {
        return __('Inventory Transfer Requests');
    }

    public static function getModelLabel(): string
    {
        return __('Inventory Transfer Request');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Inventory Transfer Requests');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('SAP Management');
    }

    public static function getEloquentQuery(): Builder
    {
        $db = 'PPTC_V5_PROD';

        $query = parent::getEloquentQuery();

        if ($db) {
            $query->where('sap_database', $db);
        }

        $user = auth()->user();
        // Only apply warehouse filter for non-Super Admin users (e.g. Branch Managers)
        if ($user && $user->warehouse_code && !$user->hasRole('Super Admin')) {
            $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
            if (!empty($codes)) {
                $query->where(function ($q) use ($codes) {
                    $q->whereIn('from_warehouse', $codes)
                        ->orWhereIn('to_warehouse', $codes);
                });
            }
        }

        return $query;
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Transfer Details'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('doc_num')
                            ->label(__('Document Number'))
                            ->disabled(),
                        Forms\Components\TextInput::make('document_status')
                            ->label(__('SAP Status'))
                            ->disabled(),
                        Forms\Components\ToggleButtons::make('internal_status')
                            ->label(__('Workflow Status'))
                            ->options([
                                \App\Models\StockTransfer::STATUS_NEW => __('New'),
                                \App\Models\StockTransfer::STATUS_SHIPPED => __('Shipped'),
                                \App\Models\StockTransfer::STATUS_COMPLETED => __('Completed'),
                            ])
                            ->colors([
                                \App\Models\StockTransfer::STATUS_NEW => 'gray',
                                \App\Models\StockTransfer::STATUS_SHIPPED => 'warning',
                                \App\Models\StockTransfer::STATUS_COMPLETED => 'success',
                            ])
                            ->icons([
                                \App\Models\StockTransfer::STATUS_NEW => 'heroicon-m-document',
                                \App\Models\StockTransfer::STATUS_SHIPPED => 'heroicon-m-truck',
                                \App\Models\StockTransfer::STATUS_COMPLETED => 'heroicon-m-check-badge',
                            ])
                            ->inline()
                            ->disabled()
                            ->columnSpanFull(),
                        Forms\Components\TextInput::make('from_warehouse')
                            ->label(__('From Warehouse'))
                            ->disabled(),
                        Forms\Components\TextInput::make('to_warehouse')
                            ->label(__('To Warehouse'))
                            ->disabled(),
                        Forms\Components\DatePicker::make('doc_date')
                            ->label(__('Document Date'))
                            ->disabled(),
                    ]),

                Forms\Components\Section::make(__('الشحنات (Shipments)'))
                    ->hidden(fn (?StockTransfer $record) => !$record)
                    ->schema([
                        Forms\Components\TextInput::make('expected_shipments_count')
                            ->label(__('عدد الشحنات'))
                            ->numeric()
                            ->minValue(1)
                            ->formatStateUsing(fn (?StockTransfer $record) => $record ? max(1, $record->shipments()->count()) : 1)
                            ->dehydrated(false)
                            ->live(onBlur: true)
                            ->disabled(function ($livewire) {
                                if (!isset($livewire->record)) return true;
                                if ($livewire->record->internal_status !== \App\Models\StockTransfer::STATUS_NEW) return true;
                                $user = auth()->user();
                                $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                                $codes = array_filter($codes ?: []);
                                if (empty($codes)) return false; // Admin
                                return !in_array($livewire->record->from_warehouse, $codes);
                            })
                            ->afterStateUpdated(function (Forms\Get $get, Forms\Set $set, $state) {
                                $count = (int) $state;
                                $shipments = $get('shipments') ?? [];
                                $currentCount = count($shipments);
                                
                                if ($count > $currentCount) {
                                    for ($i = $currentCount; $i < $count; $i++) {
                                        $shipments[(string) \Illuminate\Support\Str::uuid()] = [
                                            'tracking_number' => null,
                                            'is_received' => false,
                                        ];
                                    }
                                    $set('shipments', $shipments);
                                } elseif ($count < $currentCount) {
                                    $shipments = array_slice($shipments, 0, $count, true);
                                    $set('shipments', $shipments);
                                }
                            }),

                        Forms\Components\Repeater::make('shipments')
                            ->relationship()
                            ->label('')
                            ->schema([
                                Forms\Components\Grid::make(3)->schema([
                                    Forms\Components\TextInput::make('tracking_number')
                                        ->label(__('رقم التتبع'))
                                        ->columnSpan(2)
                                        ->disabled(function ($livewire) {
                                            if (!isset($livewire->record)) return true;
                                            if ($livewire->record->internal_status !== \App\Models\StockTransfer::STATUS_NEW) return true;
                                            $user = auth()->user();
                                            $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                                            $codes = array_filter($codes ?: []);
                                            if (empty($codes)) return false; // Admin
                                            return !in_array($livewire->record->from_warehouse, $codes);
                                        }),
                                    Forms\Components\Toggle::make('is_received')
                                        ->label(__('تم الاستلام'))
                                        ->columnSpan(1)
                                        ->inline(false)
                                        ->disabled(function ($livewire) {
                                            if (!isset($livewire->record)) return true;
                                            $status = $livewire->record->internal_status;
                                            if (!in_array($status, [\App\Models\StockTransfer::STATUS_SHIPPED, \App\Models\StockTransfer::STATUS_PARTIALLY_RECEIVED])) return true;
                                            $user = auth()->user();
                                            $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                                            $codes = array_filter($codes ?: []);
                                            if (empty($codes)) return false; // Admin
                                            return !in_array($livewire->record->to_warehouse, $codes);
                                        }),
                                ]),
                            ])
                            ->addable(false)
                            ->deletable(false)
                            ->reorderable(false)
                            ->columnSpanFull(),
                    ]),

                Forms\Components\Section::make(__('Items'))
                    ->schema([
                        Forms\Components\Repeater::make('lines')
                            ->relationship()
                            ->schema([
                                Forms\Components\Grid::make(12)
                                    ->schema([
                                        // Left Column: Image Area
                                        Forms\Components\Placeholder::make('product_image')
                                            ->hiddenLabel()
                                            ->dehydrated(false)
                                            ->content(function ($record) {
                                                if (!$record || !$record->item_code) return '';
                                                $code = $record->item_code;
                                                $folder = substr($code, 0, 4);
                                                $url = "https://ppte.sa/img/{$folder}/{$code}.png";
                                                return new \Illuminate\Support\HtmlString("<div style='display: flex; align-items: flex-start; justify-content: center; height: 100%; padding: 0.5rem;'><img src='{$url}' alt='Product Image' style='width: 100%; max-width: 130px; object-fit: contain; border-radius: 8px;' onerror=\"this.style.display='none'\"/></div>");
                                            })
                                            ->columnSpan(2),

                                        // Right Column: Data Fields Area
                                        Forms\Components\Grid::make(10)
                                            ->columnSpan(10)
                                            ->schema([
                                                // Row 1: Item Code & Description
                                                Forms\Components\TextInput::make('item_code')
                                                    ->label(__('Item Code'))
                                                    ->disabled()
                                                    ->dehydrated(false)
                                                    ->columnSpan(3),

                                                Forms\Components\TextInput::make('item_description')
                                                    ->label(__('Description'))
                                                    ->disabled()
                                                    ->dehydrated(false)
                                                    ->columnSpan(5),

                                                Forms\Components\TextInput::make('piece_barcode')
                                                    ->label(__('Barcode'))
                                                    ->formatStateUsing(function ($record) {
                                                        static $barcodeCache = null;
                                                        if ($barcodeCache === null) {
                                                            $barcodeCache = \App\Models\Product::whereNotNull('piece_barcode')
                                                                ->pluck('piece_barcode', 'item_code')
                                                                ->toArray();
                                                        }
                                                        return $barcodeCache[$record?->item_code] ?? '-';
                                                    })
                                                    ->disabled()
                                                    ->dehydrated(false)
                                                    ->columnSpan(2),

                                                // Row 2: All Quantities & Status beautifully aligned
                                                Forms\Components\TextInput::make('quantity')
                                                    ->label(__('SAP Sent Qty'))
                                                    ->numeric()
                                                    ->disabled()
                                                    ->dehydrated(false)
                                                    ->columnSpan(2),

                                                Forms\Components\TextInput::make('sent_quantity')
                                                    ->label(__('Sent Qty'))
                                                    ->numeric()
                                                    ->default(0)
                                                    ->minValue(0)
                                                    ->columnSpan(2)
                                                    // Editable only by Sender when Status is New
                                                    ->disabled(function ($livewire) {
                                                        if (!isset($livewire->record)) return true;
                                                        $record = $livewire->record;
                                                        if ($record->internal_status !== \App\Models\StockTransfer::STATUS_NEW) return true;
                                                        $user = auth()->user();
                                                        $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                                                        $codes = array_filter($codes ?: []);
                                                        if (empty($codes)) return false; // Allows super admins
                                                        return !in_array($record->from_warehouse, $codes);
                                                    }),

                                                Forms\Components\TextInput::make('received_quantity')
                                                    ->label(__('SAP Received Qty'))
                                                    ->numeric()
                                                    ->disabled()
                                                    ->dehydrated(false)
                                                    ->columnSpan(2),

                                                Forms\Components\TextInput::make('actual_received_quantity')
                                                    ->label(__('Actual Received Qty'))
                                                    ->numeric()
                                                    ->default(0)
                                                    ->minValue(0)
                                                    ->columnSpan(2)
                                                    ->disabled(function ($livewire) {
                                                        if (!isset($livewire->record)) return true;
                                                        $record = $livewire->record;
                                                        if ($record->internal_status !== \App\Models\StockTransfer::STATUS_SHIPPED) return true;
                                                        $user = auth()->user();
                                                        $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                                                        $codes = array_filter($codes ?: []);
                                                        if (empty($codes)) return false; // Allows super admins
                                                        return !in_array($record->to_warehouse, $codes);
                                                    }),

                                                Forms\Components\TextInput::make('line_status')
                                                    ->label(__('Line Status'))
                                                    ->disabled()
                                                    ->dehydrated(false)
                                                    ->columnSpan(2),
                                            ]),
                                    ]),
                            ])
                            ->addable(false)
                            ->deletable(false)
                            ->columnSpanFull(),
                    ]),
                Forms\Components\Placeholder::make('barcode_listener')
                    ->hiddenLabel()
                    ->content(function () {
                        return view('filament.resources.stock-transfer-resource.pages.barcode-listener');
                    })
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('doc_num')->label(__('Document Number'))->searchable()->sortable(),
                Tables\Columns\TextColumn::make('from_warehouse')->label(__('From Warehouse'))->searchable(),
                Tables\Columns\TextColumn::make('to_warehouse')->label(__('To Warehouse'))->searchable(),
                Tables\Columns\TextColumn::make('doc_date')->label(__('Document Date'))->date()->sortable(),
                Tables\Columns\TextColumn::make('document_status')->label(__('SAP Status'))
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => __($state === 'bost_Open' ? 'Open' : 'Closed'))
                    ->colors([
                        'success' => 'bost_Open',
                        'danger' => 'bost_Close',
                    ]),
                Tables\Columns\TextColumn::make('internal_status')
                    ->label(__('Workflow Status'))
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => __($state))
                    ->colors([
                        'gray' => \App\Models\StockTransfer::STATUS_NEW,
                        'warning' => \App\Models\StockTransfer::STATUS_SHIPPED,
                        'teal' => \App\Models\StockTransfer::STATUS_PARTIALLY_RECEIVED,
                        'info' => \App\Models\StockTransfer::STATUS_RECEIVED,
                        'success' => \App\Models\StockTransfer::STATUS_COMPLETED,
                    ]),
                Tables\Columns\TextColumn::make('created_at')->label(__('Created At'))->dateTime()->sortable()->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('shipments_progress')
                    ->label(__('الشحنات المستلمة'))
                    ->state(function (StockTransfer $record): string {
                        $total = $record->shipments()->count();
                        if ($total === 0) return '-';
                        $received = $record->shipments()->where('is_received', true)->count();
                        return "{$received} / {$total}";
                    })
                    ->badge()
                    ->color(function (StockTransfer $record): string {
                        $total = $record->shipments()->count();
                        if ($total === 0) return 'gray';
                        $received = $record->shipments()->where('is_received', true)->count();
                        if ($received === $total) return 'success';
                        if ($received > 0) return 'teal';
                        return 'gray';
                    }),


                // SAP/Base Sent Quantity
                Tables\Columns\TextColumn::make('sap_sent_quantity')
                    ->label(__('SAP Sent Quantity'))
                    ->state(function (StockTransfer $record): string {
                        return (string) $record->lines->sum('quantity');
                    }),

                // Sent Quantity (Internal)
                Tables\Columns\TextColumn::make('sent_quantity')
                    ->label(__('Sent Quantity'))
                    ->state(function (StockTransfer $record): string {
                        $total = $record->lines->sum('quantity');
                        $sent = $record->lines->sum('sent_quantity');
                        $pct = $total > 0 ? round(($sent / $total) * 100) : 0;
                        return "{$sent} ({$pct}%)";
                    }),

                // SAP Received Quantity
                Tables\Columns\TextColumn::make('sap_received_quantity')
                    ->label(__('SAP Received Quantity'))
                    ->state(function (StockTransfer $record): string {
                        $total = $record->lines->sum('quantity');
                        $received = $record->lines->sum('received_quantity');
                        $pct = $total > 0 ? round(($received / $total) * 100) : 0;
                        return "{$received} ({$pct}%)";
                    }),

                // Actual Received Quantity (Internal)
                Tables\Columns\TextColumn::make('actual_received_quantity')
                    ->label(__('Actual Received Quantity'))
                    ->state(function (StockTransfer $record): string {
                        $total = $record->lines->sum('quantity');
                        $actual = $record->lines->sum('actual_received_quantity');
                        $pct = $total > 0 ? round(($actual / $total) * 100) : 0;
                        return "{$actual} ({$pct}%)";
                    }),
            ])
            ->filters([
                // Overdue Filter (Open > 7 days)
                Tables\Filters\TernaryFilter::make('is_overdue')
                    ->label(__('Show Overdue Only (> 1 Week)'))
                    ->placeholder(__('All Transfers'))
                    ->trueLabel(__('Overdue Only'))
                    ->falseLabel(__('Normal'))
                    ->queries(
                        true: fn (Builder $query) => $query->whereIn('internal_status', [
                            \App\Models\StockTransfer::STATUS_NEW,
                            \App\Models\StockTransfer::STATUS_SHIPPED
                        ])->where('doc_date', '<', \Carbon\Carbon::now()->subDays(7)),
                        false: fn (Builder $query) => $query->where(fn ($q) => 
                            $q->whereNotIn('internal_status', [
                                \App\Models\StockTransfer::STATUS_NEW,
                                \App\Models\StockTransfer::STATUS_SHIPPED
                            ])->orWhere('doc_date', '>=', \Carbon\Carbon::now()->subDays(7))
                        ),
                        blank: fn (Builder $query) => $query, // In this case, we don't apply any filter
                    ),
                    
                // From Warehouse Filter
                Tables\Filters\SelectFilter::make('from_warehouse')
                    ->label(__('From Warehouse'))
                    ->options(\App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code'))
                    ->searchable(),

                // To Warehouse Filter

                // Document Date Filter
                Tables\Filters\Filter::make('doc_date')
                    ->form([
                        Forms\Components\DatePicker::make('date_from')->label(__('Date From')),
                        Forms\Components\DatePicker::make('date_to')->label(__('Date To')),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        return $query
                            ->when(
                                $data['date_from'],
                                fn(Builder $query, $date) => $query->whereDate('doc_date', '>=', $date)
                            )
                            ->when(
                                $data['date_to'],
                                fn(Builder $query, $date) => $query->whereDate('doc_date', '<=', $date)
                            );
                    }),

                // SAP Status Filter
                Tables\Filters\SelectFilter::make('document_status')
                    ->label(__('SAP Status'))
                    ->options([
                        'bost_Open' => __('Open'),
                        'bost_Close' => __('Closed'),
                    ])
                    ->default('bost_Open'),

                // Internal Status Filter
                Tables\Filters\SelectFilter::make('internal_status')
                    ->label(__('Workflow Status'))
                    ->options([
                        \App\Models\StockTransfer::STATUS_NEW => __('New'),
                        \App\Models\StockTransfer::STATUS_SHIPPED => __('Shipped'),
                        \App\Models\StockTransfer::STATUS_RECEIVED => __('Received'),
                        \App\Models\StockTransfer::STATUS_COMPLETED => __('Completed'),
                    ]),

                // Warehouse Filters
                Tables\Filters\SelectFilter::make('from_warehouse')
                    ->label(__('From Warehouse'))
                    ->options(function () {
                        return \App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code')->toArray();
                    })
                    ->searchable(),

                Tables\Filters\SelectFilter::make('to_warehouse')
                    ->label(__('To Warehouse'))
                    ->options(function () {
                        return \App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code')->toArray();
                    })
                    ->searchable(),

                // SAP Received Qty Filter
                Tables\Filters\Filter::make('sap_received_qty')
                    ->label(__('SAP Received Quantity'))
                    ->form([
                        Forms\Components\TextInput::make('min_qty')->numeric()->label(__('Min Received Qty')),
                        Forms\Components\TextInput::make('max_qty')->numeric()->label(__('Max Received Qty')),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        $lineTable = (new StockTransferLine)->getTable();
                        $headerTable = (new StockTransfer)->getTable();
                        return $query
                            ->when(
                                $data['min_qty'],
                                fn(Builder $query, $qty) => $query->whereRaw("(SELECT SUM(received_quantity) FROM $lineTable WHERE stock_transfer_id = $headerTable.id) >= ?", [$qty])
                            )
                            ->when(
                                $data['max_qty'],
                                fn(Builder $query, $qty) => $query->whereRaw("(SELECT SUM(received_quantity) FROM $lineTable WHERE stock_transfer_id = $headerTable.id) <= ?", [$qty])
                            );
                    }),

                // Received Percentage Filter
                Tables\Filters\Filter::make('received_progress')
                    ->label(__('Received Progress'))
                    ->form([
                        Forms\Components\TextInput::make('min_pct')->numeric()->label(__('Min %'))->suffix('%'),
                        Forms\Components\TextInput::make('max_pct')->numeric()->label(__('Max %'))->suffix('%'),
                    ])
                    ->query(function (Builder $query, array $data): Builder {
                        $lineTable = (new StockTransferLine)->getTable();
                        $headerTable = (new StockTransfer)->getTable();
                        // Formula: (SUM(received_quantity) / NULLIF(SUM(quantity), 0)) * 100
                        $subquery = "(SELECT (SUM(received_quantity) / NULLIF(SUM(quantity), 0)) * 100 FROM $lineTable WHERE stock_transfer_id = $headerTable.id)";

                        return $query
                            ->when(
                                $data['min_pct'],
                                fn(Builder $query, $pct) => $query->whereRaw("$subquery >= ?", [$pct])
                            )
                            ->when(
                                $data['max_pct'],
                                fn(Builder $query, $pct) => $query->whereRaw("$subquery <= ?", [$pct])
                            );
                    }),
            ])
            ->headerActions([
                Tables\Actions\Action::make('import_from_sap')
                    ->label(__('Import from SAP'))
                    ->icon('heroicon-o-arrow-down-tray')
                    ->visible(fn () => !auth()->user()?->hasRole('Stakeholder'))
                    ->action(function () {
                        try {
                            $service = app(StockTransferService::class);
                            $result = $service->importFromSap();

                            // Handle legacy return (int) if deploy is partial, but we expect array now
                            if (is_int($result)) {
                                $msg = __('Imported :count records.', ['count' => $result]);
                            } else {
                                $msg = __("Sync Complete.\nNew: :new\nUpdated: :updated\nSkipped: :skipped", [
                                    'new' => $result['new'],
                                    'updated' => $result['updated'],
                                    'skipped' => $result['skipped'],
                                ]);

                                // SMS Notification Logic
                                if ($result['new'] > 0 || $result['updated'] > 0) {
                                    $smsMsg = "Stock Transfer Import:\nNew: {$result['new']}, Updated: {$result['updated']}.";

                                    $recipients = \App\Models\User::where('receive_sms_on_stock_transfer_import', true)
                                        ->whereNotNull('mobile_number')
                                        ->pluck('mobile_number')
                                        ->toArray();

                                    if (!empty($recipients)) {
                                        $smsService = new \App\Services\SMS\TaqnyatService();
                                        $smsService->sendSms($recipients, $smsMsg);
                                    }
                                }
                            }

                            Notification::make()
                                ->title(__('Import Result'))
                                ->body($msg)
                                ->success()
                                ->persistent() // Keep it visible for debugging
                                ->send();
                        } catch (\Exception $e) {
                            Notification::make()
                                ->title(__('Import Failed'))
                                ->body($e->getMessage())
                                ->danger()
                                ->send();
                        }
                    }),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()
                    ->label(__('View'))
                    ->visible(fn () => auth()->user()?->hasRole('Stakeholder')),
                Tables\Actions\EditAction::make()
                    ->label(__('Manage'))
                    ->visible(function (StockTransfer $record) {
                        $user = auth()->user();
                        if ($user && $user->hasRole('Stakeholder')) return false;
                        if ($user && $user->warehouse_code) {
                            $codes = is_array($user->warehouse_code) ? $user->warehouse_code : json_decode($user->warehouse_code, true) ?? [$user->warehouse_code];
                            $codes = array_filter($codes);
                            if (empty($codes)) return true;
                            // Sender and Receiver can manage
                            return in_array($record->to_warehouse, $codes) || in_array($record->from_warehouse, $codes);
                        }
                        return true; // Admins or no-warehouse users can inspect/edit
                    }),
            ])
            ->bulkActions([
                //
            ])
            ->modifyQueryUsing(function (Builder $query) {
                return $query->with('lines');
            });
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
            'index' => Pages\ListStockTransfers::route('/'),
            'create' => Pages\CreateStockTransfer::route('/create'), // Not really used
            'edit' => Pages\EditStockTransfer::route('/{record}/edit'),
        ];
    }
}