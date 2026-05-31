<?php

namespace App\Filament\Pages;

use App\Models\MobileAppSetting;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;

class MobileAppSettings extends Page implements HasForms
{
    public static function canAccess(): bool
    {
        return !auth()->user()->hasAnyRole(['Branch Manager', 'Operator', 'Stakeholder']);
    }

    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';
    public static function getNavigationLabel(): string
    {
        return __('Mobile App Settings');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('System Settings');
    }

    public function getTitle(): string | \Illuminate\Contracts\Support\Htmlable
    {
        return __('Mobile App Settings');
    }

    protected static ?string $slug = 'mobile-app-settings';

    // public $default_environment;
    // public $maintenance_mode;

    public ?array $data = [];

    protected static string $view = 'filament.pages.mobile-app-settings';

    public function mount(): void
    {
        $settings = MobileAppSetting::all()->pluck('value', 'key')->toArray();
        $this->form->fill($settings);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Toggle::make('maintenance_mode')
                    ->label(__('Maintenance Mode'))
                    ->helperText(__('Enable to force the mobile app into maintenance mode.'))
                    ->disabled(auth()->user()?->hasRole('Stakeholder')),
            ])
            ->statePath('data');
    }

    public function submit(): void
    {
        // Block Stakeholders from saving
        if (auth()->user()?->hasRole('Stakeholder')) {
            Notification::make()
                ->title(__('Access Denied'))
                ->body(__('Stakeholders have read-only access.'))
                ->danger()
                ->send();
            return;
        }

        $data = $this->form->getState();

        foreach ($data as $key => $value) {
            MobileAppSetting::updateOrCreate(
                ['key' => $key],
                ['value' => $value]
            );
        }

        Notification::make()
            ->title(__('Settings saved successfully'))
            ->success()
            ->send();
    }
}
