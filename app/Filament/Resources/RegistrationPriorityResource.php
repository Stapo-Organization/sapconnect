<?php

namespace App\Filament\Resources;

use App\Filament\Resources\RegistrationPriorityResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\RegistrationPriority;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Brand-level SFDA registration priority (the "FDA Registration Priority" tab).
 */
class RegistrationPriorityResource extends Resource
{
    use ReadOnlyStakeholder;

    protected static ?string $model = RegistrationPriority::class;

    protected static ?string $navigationIcon = 'heroicon-o-flag';

    public static function getNavigationGroup(): ?string { return __('Supply Chain'); }
    public static function getNavigationLabel(): string { return __('Registration Priority'); }
    public static function getModelLabel(): string { return __('Registration Priority'); }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\TextInput::make('brand_code')
                ->label('Brand Code')
                ->required()
                ->maxLength(255),
            Forms\Components\TextInput::make('brand_name')
                ->label('Brand Name')
                ->maxLength(255),
            Forms\Components\TextInput::make('priority')
                ->label('Priority (1 = highest)')
                ->numeric()
                ->default(0)
                ->required(),
            Forms\Components\Textarea::make('notes')
                ->label('Notes')
                ->columnSpanFull(),
        ])->columns(3);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('priority')
                    ->label('Priority')
                    ->sortable()
                    ->badge()
                    ->color('primary'),
                Tables\Columns\TextColumn::make('brand_code')
                    ->label('Brand Code')
                    ->searchable(),
                Tables\Columns\TextColumn::make('brand_name')
                    ->label('Brand Name')
                    ->searchable(),
                Tables\Columns\TextColumn::make('notes')
                    ->label('Notes')
                    ->limit(50),
            ])
            ->defaultSort('priority', 'asc')
            ->actions([
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListRegistrationPriorities::route('/'),
            'create' => Pages\CreateRegistrationPriority::route('/create'),
            'edit'   => Pages\EditRegistrationPriority::route('/{record}/edit'),
        ];
    }
}
