<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SmsCampaignResource\Pages;
use App\Models\SmsCampaign;
use App\Services\Sms\CampaignService;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;

class SmsCampaignResource extends Resource
{
    public static function canViewAny(): bool
    {
        return !auth()->user()->hasRole('Branch Manager');
    }

    protected static ?string $model = SmsCampaign::class;

    protected static ?string $navigationIcon = 'heroicon-o-chat-bubble-left-right';

    public static function getNavigationLabel(): string
    {
        return __('SMS Campaigns');
    }

    public static function getModelLabel(): string
    {
        return __('SMS Campaign');
    }

    public static function getPluralModelLabel(): string
    {
        return __('SMS Campaigns');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('SMS Management');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                TextInput::make('name')
                    ->label(__('Name'))
                    ->required()
                    ->maxLength(255),
                Textarea::make('message_body')
                    ->label(__('Message Body'))
                    ->required()
                    ->rows(5)
                    ->helperText(__('Use {Variable} to insert dynamic data from Excel.')),
                FileUpload::make('file_path')
                    ->required()
                    ->label(__('Recipient File (Excel/CSV)'))
                    ->disk('local')
                    ->directory('sms-campaigns')
                    ->preserveFilenames()
                    ->acceptedFileTypes(['text/csv', 'text/plain', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')->label(__('Name'))->searchable(),
                Tables\Columns\BadgeColumn::make('status')
                    ->label(__('Status'))
                    ->colors([
                        'gray' => 'draft',
                        'warning' => 'processing',
                        'success' => 'completed',
                        'danger' => 'failed',
                    ])
                    ->formatStateUsing(fn ($state) => __($state)),
                Tables\Columns\TextColumn::make('total_recipients')->label(__('Total')),
                Tables\Columns\TextColumn::make('sent_count')->label(__('Sent')),
                Tables\Columns\TextColumn::make('failed_count')->label(__('Failed')),
                Tables\Columns\TextColumn::make('created_at')->label(__('Created At'))->dateTime()->sortable(),
            ])
            ->filters([
                //
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
            'index' => Pages\ListSmsCampaigns::route('/'),
            'create' => Pages\CreateSmsCampaign::route('/create'),
            'edit' => Pages\EditSmsCampaign::route('/{record}/edit'),
        ];
    }
}
