<?php

namespace App\Filament\Resources;

use App\Filament\Resources\EmailNotificationResource\Pages;
use App\Models\EmailNotification;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class EmailNotificationResource extends Resource
{
    protected static ?string $model = EmailNotification::class;

    protected static ?string $navigationIcon = 'heroicon-o-envelope';

    public static function getNavigationLabel(): string
    {
        return __('Email Notifications');
    }

    public static function getModelLabel(): string
    {
        return __('Email Notification');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Email Notifications');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Settings');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make(__('General Settings'))
                    ->columns(2)
                    ->schema([
                        Forms\Components\TextInput::make('event_name')
                            ->label(__('Event Name'))
                            ->required()
                            ->unique(ignoreRecord: true)
                            ->placeholder('e.g., stock_transfer_created')
                            ->helperText(__('A unique system code used to trigger this email.')),
                        
                        Forms\Components\Toggle::make('is_active')
                            ->label(__('Is Active'))
                            ->default(true)
                            ->inline(false)
                            ->helperText(__('If disabled, emails for this event will not be sent.')),

                        Forms\Components\Select::make('recipient_roles')
                            ->label(__('Target Recipients'))
                            ->multiple()
                            ->options([
                                'sender_warehouse' => __('Sender Warehouse Administrators'),
                                'receiver_warehouse' => __('Receiver Warehouse Administrators'),
                                'system_admin' => __('System Administrators'),
                            ])
                            ->helperText(__('Select which user roles will dynamically receive this email based on the event context.')),

                        Forms\Components\TagsInput::make('cc_emails')
                            ->label(__('Static CC Emails'))
                            ->placeholder(__('Add email address'))
                            ->helperText(__('These specific emails will always receive a copy when this event triggers.')),
                    ]),

                Forms\Components\Section::make(__('Email Content (Arabic)'))
                    ->schema([
                        Forms\Components\TextInput::make('subject_ar')
                            ->label(__('Arabic Subject'))
                            ->required(),
                        Forms\Components\RichEditor::make('body_ar')
                            ->label(__('Arabic Body'))
                            ->required()
                            ->helperText(__('Available variables depend on event. Example: {doc_num}, {from_warehouse}')),
                    ]),

                Forms\Components\Section::make(__('Email Content (English)'))
                    ->schema([
                        Forms\Components\TextInput::make('subject_en')
                            ->label(__('English Subject'))
                            ->required(),
                        Forms\Components\RichEditor::make('body_en')
                            ->label(__('English Body'))
                            ->required()
                            ->helperText(__('Available variables depend on event. Example: {doc_num}, {from_warehouse}')),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('event_name')
                    ->label(__('Event Name'))
                    ->searchable()
                    ->sortable(),
                
                Tables\Columns\IconColumn::make('is_active')
                    ->label(__('Active'))
                    ->boolean()
                    ->sortable(),

                Tables\Columns\TextColumn::make('subject_ar')
                    ->label(__('Arabic Subject'))
                    ->limit(50)
                    ->searchable(),

                Tables\Columns\TextColumn::make('subject_en')
                    ->label(__('English Subject'))
                    ->limit(50)
                    ->searchable(),
                
                Tables\Columns\TextColumn::make('updated_at')
                    ->label(__('Last Updated'))
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')
                    ->label(__('Active status')),
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

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListEmailNotifications::route('/'),
            'create' => Pages\CreateEmailNotification::route('/create'),
            'edit' => Pages\EditEmailNotification::route('/{record}/edit'),
        ];
    }
}
