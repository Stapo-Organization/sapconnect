<?php

namespace App\Filament\Pages\Auth;

use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Form;
use Filament\Pages\Auth\EditProfile as BaseEditProfile;

class EditProfile extends BaseEditProfile
{
    public function form(Form $form): Form
    {
        return $form
            ->schema([
                $this->getNameFormComponent(),
                $this->getEmailFormComponent(),
                TextInput::make('mobile_number')
                    ->label('Mobile Number')
                    ->tel()
                    ->regex('/^9665[0-9]{8}$/')
                    ->unique(ignoreRecord: true)
                    ->helperText('Format: 9665xxxxxxxx (Start with 966)')
                    ->required(false), // Optional if not strict, or true if strict
                TextInput::make('auth_token')
                    ->label('Auth Token')
                    ->disabled()
                    ->dehydrated(false) // Don't save this field directly, handled by action
                    ->suffixAction(
                        \Filament\Forms\Components\Actions\Action::make('regenerate_token')
                            ->icon('heroicon-o-arrow-path')
                            ->requiresConfirmation()
                            ->action(function ($record, $state, $component) { // EditProfile form is mostly not bound to record in same way, but let's check. 
                                // Actually, in EditProfile, the model is the auth user.
                                // But EditProfile doesn't pass $record to action closure easily in all versions.
                                // We can use auth()->user().
                                $user = auth()->user();
                                $token = \Illuminate\Support\Str::random(60);
                                $user->auth_token = $token;
                                $user->save();

                                // We need to update the state of the input
                                // But components on EditProfile page might be static?
                                // Let's try to notify user or refresh.
                                // Better: Set state.
                    
                                \Filament\Notifications\Notification::make()
                                    ->title('Token Generated')
                                    ->success()
                                    ->send();

                                // This might not update the UI immediately without a refresh.
                                // To update UI, we might need livewire wire:model or set state.
                                // $component->state($token); // This works if $component is passed
                                return $token;
                            })
                            // If we return value, does it update state? No, Filament actions are void usually.
                            // But we can use after()
                            ->after(function ($livewire) {
                                // Refresh the form data
                                $livewire->fillForm();
                            })
                    ),
                FileUpload::make('avatar_url')
                    ->avatar()
                    ->image()
                    ->directory('avatars')
                    ->visibility('public'),
                $this->getPasswordFormComponent(),
                $this->getPasswordConfirmationFormComponent(),
            ]);
    }
}
