<?php

namespace App\Filament\Resources;

use App\Filament\Resources\EmailLogResource\Pages;
use App\Models\EmailLog;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class EmailLogResource extends Resource
{
    protected static ?string $model = EmailLog::class;

    protected static ?string $navigationIcon = 'heroicon-o-chat-bubble-left-right';

    public static function getNavigationLabel(): string
    {
        return __('Email Logs');
    }

    public static function getModelLabel(): string
    {
        return __('Email Log');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Email Logs');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Settings');
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('Log Details'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('recipient')
                            ->label(__('Recipient'))
                            ->disabled(),
                        Forms\Components\TextInput::make('subject')
                            ->label(__('Subject'))
                            ->disabled(),
                        Forms\Components\TextInput::make('status')
                            ->label(__('Status'))
                            ->disabled(),
                        Forms\Components\DateTimePicker::make('sent_at')
                            ->label(__('Sent At'))
                            ->disabled(),
                        Forms\Components\Textarea::make('error_message')
                            ->label(__('Error Message'))
                            ->columnSpanFull()
                            ->disabled(),
                    ])
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('subject')
                    ->label(__('Subject'))
                    ->searchable()
                    ->limit(50),
                Tables\Columns\TextColumn::make('recipient')
                    ->label(__('Recipient'))
                    ->searchable(),
                Tables\Columns\BadgeColumn::make('status')
                    ->label(__('Status'))
                    ->colors([
                        'success' => 'success',
                        'danger' => 'failed',
                    ]),
                Tables\Columns\TextColumn::make('sent_at')
                    ->label(__('Sent At'))
                    ->dateTime()
                    ->sortable(),
                Tables\Columns\TextColumn::make('created_at')
                    ->label(__('Created At'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label(__('Status'))
                    ->options([
                        'success' => __('Success'),
                        'failed' => __('Failed'),
                    ]),
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

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListEmailLogs::route('/'),
            'view' => Pages\ViewEmailLog::route('/{record}'),
        ];
    }
}
