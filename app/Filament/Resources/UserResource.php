<?php

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Filament\Traits\ReadOnlyStakeholder;
use App\Models\User;
use App\Support\AppFeatures;
use App\Support\NotificationPreferences;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Hash;

class UserResource extends Resource
{
    use ReadOnlyStakeholder;

    public static function canViewAny(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator', 'Stakeholder']);
    }

    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    public static function getNavigationLabel(): string
    {
        return __('Users');
    }

    public static function getModelLabel(): string
    {
        return __('User');
    }

    public static function getPluralModelLabel(): string
    {
        return __('Users');
    }
    
    public static function getNavigationGroup(): ?string
    {
        return __('System Settings');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('name')
                    ->label(__('Name'))
                    ->required()
                    ->maxLength(255),
                Forms\Components\TextInput::make('email')
                    ->label(__('Email'))
                    ->email()
                    ->required()
                    ->maxLength(255),
                Forms\Components\TextInput::make('mobile_number')
                    ->label(__('Mobile Number'))
                    ->tel()
                    ->maxLength(20)
                    ->nullable()
                    ->default(null)
                    ->dehydrateStateUsing(fn ($state) => blank($state) ? null : $state)
                    ->helperText(__('Format: 9665...')),
                Forms\Components\TextInput::make('password')
                    ->label(__('Password'))
                    ->password()
                    ->dehydrateStateUsing(fn($state) => Hash::make($state))
                    ->dehydrated(fn($state) => filled($state))
                    ->required(fn(string $context): bool => $context === 'create'),

                // Spatie Roles & Permissions
                Forms\Components\Select::make('roles')
                    ->label(__('Roles'))
                    ->relationship('roles', 'name')
                    ->multiple()
                    ->preload()
                    ->searchable()
                    ->helperText(__('Select "Branch Manager" to limit access only to specific warehouses.')),

                // Reference: Warehouse Code for Stock Transfers
                Forms\Components\Select::make('warehouse_code')
                    ->label(__('Assigned Warehouses (Branch Manager)'))
                    ->helperText(__('Select the warehouse(s) this user manages. Required if role is Branch Manager.'))
                    ->options(\App\Models\Warehouse::pluck('warehouse_name', 'warehouse_code'))
                    ->multiple()
                    ->searchable()
                    ->preload(),

                Forms\Components\Section::make(__('Notifications'))
                    ->schema([
                        Forms\Components\Toggle::make('receive_sms_on_zid_import')
                            ->label(__('SMS: Zid Import'))
                            ->helperText(__('Notify this user when Zid orders are synced.'))
                            ->default(false),

                        Forms\Components\Toggle::make('receive_sms_on_stock_transfer_import')
                            ->label(__('SMS: Stock Transfers'))
                            ->helperText(__('Notify this user when new stock transfers are imported.'))
                            ->default(false),
                    ])->columns(2),

                static::appPermissionsSection(),

                static::appNotificationsSection(),
            ]);
    }

    /**
     * قسم "صلاحيات التطبيق" — لكل خاصية وكل إجراء حالة ثلاثية:
     *   حسب الدور (وراثة) / مسموح (منح استثنائي) / ممنوع (منع استثنائي).
     * الحالة تُخزّن في feature_overrides ثم تُحفظ في user_feature_overrides عبر HandlesFeatureOverrides.
     */
    public static function appPermissionsSection(): Forms\Components\Section
    {
        $fieldsets = [];

        foreach (AppFeatures::all() as $feature => $def) {
            $controls = [];
            foreach (($def['actions'] ?? []) as $action => $actionLabel) {
                $controls[] = Forms\Components\ToggleButtons::make("feature_overrides.{$feature}.{$action}")
                    ->label($actionLabel)
                    ->inline()
                    ->default('inherit')
                    ->options([
                        'inherit' => __('حسب الدور'),
                        'allow'   => __('مسموح'),
                        'deny'    => __('ممنوع'),
                    ])
                    ->colors([
                        'inherit' => 'gray',
                        'allow'   => 'success',
                        'deny'    => 'danger',
                    ])
                    ->icons([
                        'inherit' => 'heroicon-o-minus',
                        'allow'   => 'heroicon-o-check',
                        'deny'    => 'heroicon-o-x-mark',
                    ]);
            }

            $defaultRoles = implode('، ', $def['default_roles'] ?? []);

            $fieldsets[] = Forms\Components\Fieldset::make($def['label'] ?? $feature)
                ->schema(array_merge(
                    [Forms\Components\Placeholder::make("hint_{$feature}")
                        ->hiddenLabel()
                        ->content($defaultRoles
                            ? __('الافتراضي لهذه الخاصية لأدوار: ') . $defaultRoles
                            : __('لا أدوار افتراضية — مُتاحة فقط بمنح استثنائي.'))],
                    $controls,
                ))
                ->columns(1);
        }

        return Forms\Components\Section::make(__('صلاحيات التطبيق (مدير المعرض)'))
            ->description(__('تحكّم بما يراه هذا المستخدم في التطبيق. "حسب الدور" = يرث افتراضي دوره؛ استخدم "مسموح"/"ممنوع" كاستثناء فردي.'))
            ->icon('heroicon-o-shield-check')
            ->collapsible()
            ->schema($fieldsets);
    }

    /**
     * قسم "تفضيلات الإشعارات" — لكل تنبيه قناة رباعية الاختيار:
     *   حسب الافتراضي (وراثة، لا سطر) / بريد / تطبيق / الاثنين.
     * تُخزَّن في notification_prefs ثم تُحفظ في notification_preferences عبر HandlesNotificationPreferences.
     */
    public static function appNotificationsSection(): Forms\Components\Section
    {
        $byGroup = [];
        foreach (NotificationPreferences::all() as $key => $def) {
            if (! ($def['user_configurable'] ?? false)) {
                continue;
            }
            $byGroup[$def['group'] ?? 'أخرى'][$key] = $def;
        }

        $fieldsets = [];
        foreach ($byGroup as $group => $events) {
            $controls = [];
            foreach ($events as $key => $def) {
                $controls[] = Forms\Components\ToggleButtons::make("notification_prefs.{$key}")
                    ->label($def['label'] ?? $key)
                    ->inline()
                    ->default('inherit')
                    ->options([
                        'inherit' => __('حسب الافتراضي'),
                        'email'   => __('بريد'),
                        'push'    => __('تطبيق'),
                        'both'    => __('الاثنين'),
                    ])
                    ->colors([
                        'inherit' => 'gray',
                        'email'   => 'warning',
                        'push'    => 'info',
                        'both'    => 'success',
                    ])
                    ->icons([
                        'inherit' => 'heroicon-o-minus',
                        'email'   => 'heroicon-o-envelope',
                        'push'    => 'heroicon-o-device-phone-mobile',
                        'both'    => 'heroicon-o-check-circle',
                    ]);
            }

            $fieldsets[] = Forms\Components\Fieldset::make($group)
                ->schema($controls)
                ->columns(1);
        }

        return Forms\Components\Section::make(__('تفضيلات الإشعارات'))
            ->description(__('قناة كل تنبيه لهذا المستخدم: "حسب الافتراضي" = وراثة إعداد النظام؛ أو خصّص بريد / تطبيق / الاثنين.'))
            ->icon('heroicon-o-bell')
            ->collapsible()
            ->collapsed()
            ->schema($fieldsets);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label(__('Name'))
                    ->searchable()
                    ->description(fn(User $record) => $record->email),
                Tables\Columns\TextColumn::make('mobile_number')
                    ->label(__('Mobile Number'))
                    ->searchable(),

                Tables\Columns\IconColumn::make('last_activity_at')
                    ->label(__('Online Status'))
                    ->state(function (User $record) {
                        if ($record->last_activity_at && $record->last_activity_at->diffInMinutes(now()) < 5) {
                            return true;
                        }
                        return false;
                    })
                    ->icon(fn(bool $state): string => $state ? 'heroicon-s-check-circle' : 'heroicon-s-x-circle')
                    ->color(fn(bool $state): string => $state ? 'success' : 'gray')
                    ->trueIcon('heroicon-s-check-circle') // Green dot equivalent
                    ->falseIcon('heroicon-o-x-circle'),

                Tables\Columns\TextColumn::make('last_login_at')
                    ->label(__('Last Login'))
                    ->dateTime()
                    ->sortable()
                    ->since(), // Show "2 minutes ago"

                Tables\Columns\TextColumn::make('roles.name')
                    ->label(__('Roles'))
                    ->badge(),
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
            'index' => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
