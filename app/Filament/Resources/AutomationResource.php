<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AutomationResource\Pages;
use App\Filament\Resources\AutomationResource\RelationManagers;
use App\Models\Automation;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Artisan;
use Filament\Notifications\Notification;
use App\Models\AutomationLog; // Corrected Import

class AutomationResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    protected static ?string $model = Automation::class;

    protected static ?string $navigationIcon = 'heroicon-o-cpu-chip';

    public static function getNavigationLabel(): string
    {
        return __('Automations');
    }

    public static function getModelLabel(): string
    {
        return __('Automation');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Automations');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('System Settings');
    }

    public static function getEloquentQuery(): \Illuminate\Database\Eloquent\Builder
    {
        return parent::getEloquentQuery()->withoutGlobalScopes();
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Configuration'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\Select::make('preset')
                            ->label(__('Automation Type'))
                            ->options([
                                'sync_stock_transfers' => __('Import Stock Transfers'),
                                'sync_alrajhi' => __('Import Alrajhi Transactions'),
                                'sync_brands' => __('Import Brands'),
                                'sync_products' => __('Import Products'),
                                'sync_warehouses' => __('Import Warehouses'),
                            ])
                            ->reactive()
                            ->afterStateUpdated(function ($state, Forms\Get $get, Forms\Set $set) {
                                self::updateAutomationFields($state, null, $set);
                            })
                            ->dehydrated(false)
                            ->hidden(fn(string $operation) => $operation === 'edit'),

                        Forms\Components\TextInput::make('name')
                            ->label(__('Name'))
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('code')
                            ->label(__('Code'))
                            ->required()
                            ->readOnly()
                            ->unique(ignoreRecord: true),

                        Forms\Components\TextInput::make('command_signature')
                            ->label(__('Command Signature'))
                            ->required()
                            ->readOnly()
                            ->helperText(__('Mapped automatically based on Type.')),

                        Forms\Components\Select::make('schedule_frequency')
                            ->label(__('Schedule Frequency'))
                            ->options([
                                'everyMinute' => __('Every Minute'),
                                'everyFiveMinutes' => __('Every 5 Minutes'),
                                'hourly' => __('Hourly'),
                                'daily' => __('Daily'),
                                'weekly' => __('Weekly'),
                            ])
                            ->required(),
                    ]),

                Forms\Components\Section::make(__('Status & Notifications'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\Toggle::make('is_active')
                            ->label(__('Active'))
                            ->helperText(__('Enable or disable this automation schedule.')),

                        Forms\Components\Toggle::make('notify_sms')
                            ->label(__('SMS Notifications'))
                            ->helperText(__('Send SMS to subscribed admins when updates are found or errors occur.')),
                    ]),
            ]);
    }

    protected static function updateAutomationFields($preset, $database, Forms\Set $set)
    {
        if (!$preset)
            return;

        $map = [
            'sync_stock_transfers' => ['Import Stock Transfers', 'sap:sync-stock-transfers'],
            'sync_alrajhi' => ['Import Alrajhi Transactions', 'sap:sync-alrajhi'],
            'sync_brands' => ['Import Brands', 'sap:sync-brands'],
            'sync_products' => ['Import Products', 'sap:sync-products'],
            'sync_warehouses' => ['Import Warehouses', 'sap:sync-warehouses'],
        ];

        if (isset($map[$preset])) {
            $baseName = $map[$preset][0];
            $baseCode = $preset;
            $command = $map[$preset][1];

            if ($database) {
                $generatedCode = "{$baseCode}_{$database}";
                $set('name', "$baseName ($database)");
                $set('code', $generatedCode);
                $set('command_signature', "$command --code=$generatedCode");
            } else {
                $set('name', $baseName);
                $set('code', $baseCode);
                $set('command_signature', "$command --code=$baseCode");
            }
        }
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')->label(__('Name'))->searchable()->sortable(),
                Tables\Columns\TextColumn::make('command_signature')->label(__('Command Signature'))->fontFamily('mono')->color('gray'),
                Tables\Columns\TextColumn::make('schedule_frequency')->label(__('Schedule Frequency'))->badge(),
                Tables\Columns\IconColumn::make('is_active')
                    ->boolean()
                    ->label(__('Active')),
                Tables\Columns\IconColumn::make('notify_sms')
                    ->boolean()
                    ->label(__('SMS')),
                Tables\Columns\TextColumn::make('last_run_at')->dateTime()->sortable()->label(__('Last Run')),
                Tables\Columns\TextColumn::make('last_run_status')
                    ->label(__('Last Run Status'))
                    ->badge()
                    ->colors([
                        'success' => 'success',
                        'danger' => 'failed',
                        'warning' => 'warning',
                    ]),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
                Tables\Actions\Action::make('run_now')
                    ->label(__('Run Now'))
                    ->icon('heroicon-o-play')
                    ->color('primary')
                    ->requiresConfirmation()
                    ->action(function (Automation $record) {
                        try {
                            // Increase memory & time limit for heavy syncs
                            ini_set('memory_limit', '1G');
                            set_time_limit(0);

                            // Run the command synchronousl
                            // command_signature now looks like "sap:cmd --code=XYZ".
                            // Artisan::call expects command name and array of params.
                            // Simplest way: just pass the full string to call() IF it supports it?
                            // Actually, Artisan::call('cmd --opt') works in recent Laravel versions?
                            // No, usually strictly Artisan::call('cmd', params).
            
                            // Let's parse it rudimentarily:
                            $parts = explode(' ', $record->command_signature);
                            $cmd = array_shift($parts);
                            $params = ['--full' => true];
                            foreach ($parts as $part) {
                                if (str_starts_with($part, '--')) {
                                    $p = explode('=', substr($part, 2));
                                    $key = $p[0];
                                    $val = $p[1] ?? true;
                                    $params['--' . $key] = $val;
                                }
                            }

                            $exitCode = Artisan::call($cmd, $params);
                            // Reload to see updated Last Run
                            Notification::make()
                                ->title(__('Automation Triggered'))
                                ->body(Artisan::output())
                                ->success()
                                ->send();
                        } catch (\Exception $e) {
                            Notification::make()
                                ->title(__('Execution Failed'))
                                ->body($e->getMessage())
                                ->danger()
                                ->send();
                        }
                    }),
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
            RelationManagers\LogsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAutomations::route('/'),
            'create' => Pages\CreateAutomation::route('/create'),
            'edit' => Pages\EditAutomation::route('/{record}/edit'),
        ];
    }
}
