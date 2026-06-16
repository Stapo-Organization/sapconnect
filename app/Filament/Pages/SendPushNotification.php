<?php

namespace App\Filament\Pages;

use App\Models\User;
use App\Models\Warehouse;
use App\Services\NotificationRouter;
use App\Support\NotificationAudience;
use Filament\Forms\Components\KeyValue;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\ToggleButtons;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Spatie\Permission\Models\Role;

/**
 * إرسال إشعار Push يدوي لمستخدمي تطبيق مدير المعرض.
 * يستهدف: الكل / دور / فرع (مستودع) / مستخدمين محدّدين، ويوجّه عبر
 * NotificationRouter بقناة Push مفروضة (إجراء متعمَّد يُسلَّم دائماً).
 */
class SendPushNotification extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-paper-airplane';
    protected static ?string $slug = 'send-notification';
    protected static string $view = 'filament.pages.send-push-notification';

    public ?array $data = [];

    public static function canAccess(): bool
    {
        return ! auth()->user()->hasAnyRole(['Branch Manager', 'Operator', 'Stakeholder']);
    }

    public static function getNavigationLabel(): string
    {
        return 'إرسال إشعار';
    }

    public static function getNavigationGroup(): ?string
    {
        return __('System Settings');
    }

    public function getTitle(): string | \Illuminate\Contracts\Support\Htmlable
    {
        return 'إرسال إشعار للتطبيق';
    }

    public function mount(): void
    {
        $this->form->fill(['target_type' => 'all']);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                ToggleButtons::make('target_type')
                    ->label('المستهدفون')
                    ->inline()
                    ->default('all')
                    ->live()
                    ->options([
                        'all'       => 'كل المستخدمين',
                        'role'      => 'حسب الدور',
                        'warehouse' => 'حسب الفرع',
                        'users'     => 'مستخدمون محدّدون',
                    ])
                    ->icons([
                        'all'       => 'heroicon-o-users',
                        'role'      => 'heroicon-o-identification',
                        'warehouse' => 'heroicon-o-building-storefront',
                        'users'     => 'heroicon-o-user',
                    ]),

                Select::make('roles')
                    ->label('الأدوار')
                    ->multiple()
                    ->options(fn () => Role::orderBy('name')->pluck('name', 'name'))
                    ->visible(fn (Get $get) => $get('target_type') === 'role')
                    ->required(fn (Get $get) => $get('target_type') === 'role'),

                Select::make('warehouses')
                    ->label('الفروع (المستودعات)')
                    ->multiple()
                    ->searchable()
                    ->options(fn () => Warehouse::orderBy('warehouse_name')->pluck('warehouse_name', 'warehouse_code'))
                    ->visible(fn (Get $get) => $get('target_type') === 'warehouse')
                    ->required(fn (Get $get) => $get('target_type') === 'warehouse'),

                Select::make('users')
                    ->label('المستخدمون')
                    ->multiple()
                    ->searchable()
                    ->options(fn () => User::orderBy('name')->pluck('name', 'id'))
                    ->visible(fn (Get $get) => $get('target_type') === 'users')
                    ->required(fn (Get $get) => $get('target_type') === 'users'),

                TextInput::make('title')
                    ->label('عنوان الإشعار')
                    ->required()
                    ->maxLength(120),

                Textarea::make('body')
                    ->label('نص الإشعار')
                    ->required()
                    ->rows(3)
                    ->maxLength(500),

                KeyValue::make('payload')
                    ->label('بيانات إضافية (اختياري)')
                    ->keyLabel('المفتاح')
                    ->valueLabel('القيمة')
                    ->helperText('تُرسَل مع الإشعار لتوجيه التطبيق (مثل type أو معرّف).'),
            ])
            ->statePath('data');
    }

    public function send(): void
    {
        $data = $this->form->getState();

        $recipients = match ($data['target_type'] ?? 'all') {
            'role'      => NotificationAudience::byRoles($data['roles'] ?? []),
            'warehouse' => NotificationAudience::warehouseUsers($data['warehouses'] ?? []),
            'users'     => User::whereIn('id', $data['users'] ?? [])->get(),
            default     => User::query()->get(),
        };

        if ($recipients->isEmpty()) {
            Notification::make()
                ->title('لا يوجد مستلمون')
                ->body('لم يُطابق الاستهداف أي مستخدم.')
                ->warning()
                ->send();
            return;
        }

        $payload = array_merge(['type' => 'manual'], $data['payload'] ?? []);

        app(NotificationRouter::class)->route(
            'manual_broadcast',
            $recipients,
            [
                'title' => $data['title'],
                'body'  => $data['body'],
                'data'  => $payload,
            ],
            ['force_channels' => ['push']]
        );

        Notification::make()
            ->title('تم إرسال الإشعار')
            ->body("وُجِّه إلى {$recipients->count()} مستخدم (تصل الإشعارات للأجهزة المسجَّلة فقط).")
            ->success()
            ->send();

        $this->form->fill(['target_type' => $data['target_type'] ?? 'all']);
    }
}
