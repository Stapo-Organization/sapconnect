<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ApiLogResource\Pages;
use App\Models\ApiLog;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class ApiLogResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator']);
    }

    protected static ?string $model = ApiLog::class;

    protected static ?string $navigationIcon = 'heroicon-o-signal';

    public static function getNavigationLabel(): string
    {
        return __('Api Logs');
    }

    public static function getModelLabel(): string
    {
        return __('Api Log');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Api Logs');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('System');
    }

    // Logs are read-only
    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('method')
                    ->label(__('HTTP Method')),
                Forms\Components\TextInput::make('endpoint')
                    ->label(__('Endpoint')),
                Forms\Components\TextInput::make('status_code')
                    ->label(__('Status')),
                Forms\Components\TextInput::make('ip_address')
                    ->label(__('IP Address')),

                Forms\Components\Section::make(__('Payloads'))
                    ->schema([
                        Forms\Components\Textarea::make('request_payload')
                            ->rows(5),
                        Forms\Components\Textarea::make('response_body')
                            ->rows(10),
                    ])
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->label(__('Time')),
                Tables\Columns\TextColumn::make('method')
                    ->label(__('HTTP Method'))
                    ->badge()
                    ->color(fn(string $state): string => match ($state) {
                        'GET' => 'success',
                        'POST' => 'warning',
                        'PUT', 'PATCH' => 'info',
                        'DELETE' => 'danger',
                        default => 'gray',
                    }),
                Tables\Columns\TextColumn::make('endpoint')
                    ->label(__('Endpoint'))
                    ->searchable()
                    ->limit(50),
                Tables\Columns\TextColumn::make('status_code')
                    ->label(__('Status'))
                    ->badge()
                    ->color(fn(string $state): string => match (true) {
                        $state >= 200 && $state < 300 => 'success',
                        $state >= 400 && $state < 500 => 'warning',
                        $state >= 500 => 'danger',
                        default => 'gray',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('database_name')
                    ->label(__('Database'))
                    ->badge()
                    ->color('info')
                    ->sortable(),
                Tables\Columns\TextColumn::make('user.name')
                    ->label(__('User'))
                    ->placeholder(__('Guest')),
                Tables\Columns\TextColumn::make('ip_address')
                    ->label(__('IP Address')),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('method')
                    ->label(__('HTTP Method'))
                    ->options([
                        'GET' => 'GET',
                        'POST' => 'POST',
                        'PATCH' => 'PATCH',
                        'DELETE' => 'DELETE',
                    ]),
                Tables\Filters\Filter::make('errors')
                    ->label(__('Errors Only'))
                    ->query(fn(Builder $query): Builder => $query->where('status_code', '>=', 400)),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();

        // Scope to user's own logs if they are not a Super Admin (or specific high-level role)
        // Assuming 'Operator' is the restricted role. 
        // Best practice: Check if user CAN view ALL.
        // For now, simpler: If user has 'Operator' role, scope it.

        $user = auth()->user();
        if ($user && $user->hasRole('Operator')) {
            $query->where('user_id', $user->id);
        }

        return $query;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListApiLogs::route('/'),
        ];
    }
}
