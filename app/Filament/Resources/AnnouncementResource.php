<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AnnouncementResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\Announcement;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Owner-managed company news shown on the public (pre-login) landing screen
 * of the Muntajat HUB app. Served publicly via GET /api/store/landing.
 */
class AnnouncementResource extends Resource
{
    use ReadOnlyStakeholder;

    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator', 'Stakeholder']);
    }

    protected static ?string $model = Announcement::class;

    protected static ?string $navigationIcon = 'heroicon-o-newspaper';

    public static function getNavigationLabel(): string
    {
        return 'أخبار الشركة';
    }

    public static function getModelLabel(): string
    {
        return 'خبر';
    }

    public static function getPluralModelLabel(): string
    {
        return 'أخبار الشركة';
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Settings');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('المحتوى (عربي)')
                    ->schema([
                        Forms\Components\TextInput::make('title_ar')
                            ->label('العنوان')
                            ->required()
                            ->maxLength(255),
                        Forms\Components\Textarea::make('body_ar')
                            ->label('النص')
                            ->rows(5)
                            ->helperText('نص الخبر الذي يظهر للزوّار في الصفحة الرئيسية.'),
                    ]),

                Forms\Components\Section::make('المحتوى (إنجليزي — اختياري)')
                    ->collapsed()
                    ->schema([
                        Forms\Components\TextInput::make('title_en')
                            ->label('Title')
                            ->maxLength(255),
                        Forms\Components\Textarea::make('body_en')
                            ->label('Body')
                            ->rows(5),
                    ]),

                Forms\Components\Section::make('الصورة والإعدادات')
                    ->columns(2)
                    ->schema([
                        Forms\Components\FileUpload::make('image_path')
                            ->label('الصورة')
                            ->image()
                            ->imageEditor()
                            ->disk('public')
                            ->directory('announcements')
                            ->maxSize(5120)
                            ->columnSpanFull()
                            ->helperText('صورة الخبر (اختياري). يُفضّل أبعاد أفقية.'),

                        Forms\Components\TextInput::make('link_url')
                            ->label('رابط (اختياري)')
                            ->url()
                            ->maxLength(2048)
                            ->helperText('رابط يُفتح عند الضغط على الخبر.'),

                        Forms\Components\TextInput::make('sort_order')
                            ->label('الترتيب')
                            ->numeric()
                            ->default(0)
                            ->helperText('الأصغر يظهر أولاً.'),

                        Forms\Components\DateTimePicker::make('published_at')
                            ->label('تاريخ النشر')
                            ->helperText('اتركه فارغًا للنشر فورًا، أو حدّد وقتًا مستقبليًا للجدولة.'),

                        Forms\Components\Toggle::make('is_published')
                            ->label('منشور')
                            ->default(true)
                            ->inline(false)
                            ->helperText('عند الإيقاف لا يظهر الخبر للزوّار.'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('sort_order')
            ->reorderable('sort_order')
            ->columns([
                Tables\Columns\ImageColumn::make('image_url')
                    ->label('الصورة'),
                Tables\Columns\TextColumn::make('title_ar')
                    ->label('العنوان')
                    ->searchable()
                    ->limit(60),
                Tables\Columns\IconColumn::make('is_published')
                    ->label('منشور')
                    ->boolean()
                    ->sortable(),
                Tables\Columns\TextColumn::make('published_at')
                    ->label('تاريخ النشر')
                    ->dateTime()
                    ->sortable(),
                Tables\Columns\TextColumn::make('sort_order')
                    ->label('الترتيب')
                    ->sortable(),
                Tables\Columns\TextColumn::make('updated_at')
                    ->label('آخر تحديث')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('is_published')
                    ->label('حالة النشر'),
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
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAnnouncements::route('/'),
            'create' => Pages\CreateAnnouncement::route('/create'),
            'edit' => Pages\EditAnnouncement::route('/{record}/edit'),
        ];
    }
}
