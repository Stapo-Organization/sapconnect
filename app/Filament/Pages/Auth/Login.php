<?php

namespace App\Filament\Pages\Auth;

use App\Models\User;
use App\Services\Sms\TaqnyatSmsService;
use Carbon\Carbon;
use DanHarrin\LivewireRateLimiting\Exceptions\TooManyRequestsException;
use Filament\Facades\Filament;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Form;
use Filament\Http\Responses\Auth\Contracts\LoginResponse;
use Filament\Notifications\Notification;
use Filament\Pages\Auth\Login as BaseLogin;
use Illuminate\Validation\ValidationException;

class Login extends BaseLogin
{
    protected static string $view = 'filament.pages.auth.login';

    public ?string $loginMode = 'email'; // 'email' or 'otp'
    // form data is in $this->data

    public bool $otpSent = false;

    public function mount(): void
    {
        parent::mount();

        if (Filament::auth()->check()) {
            redirect()->intended(Filament::getUrl());
        }

        $this->form->fill();
    }

    public function form(Form $form): Form
    {
        if ($this->loginMode === 'otp') {
            return $form
                ->schema([
                    TextInput::make('mobile_number')
                        ->label('Mobile Number')
                        ->placeholder('e.g. 500141072')
                        ->tel()
                        ->required()
                        ->regex('/^9665[0-9]{8}$/')
                        ->readOnly(fn() => $this->otpSent),
                    TextInput::make('otp')
                        ->label('OTP Code')
                        ->placeholder('Enter 4-digit OTP')
                        ->numeric()
                        ->maxLength(4)
                        ->visible(fn() => $this->otpSent)
                        ->required(fn() => $this->otpSent),
                ])
                ->statePath('data');
        }

        // Default email/password form
        return $form
            ->schema([
                $this->getEmailFormComponent(),
                $this->getPasswordFormComponent(),
                $this->getRememberFormComponent(),
            ])
            ->statePath('data');
    }

    public function switchToOtp(): void
    {
        $this->loginMode = 'otp';
        $this->otpSent = false;
        $this->data['mobile_number'] = '';
        $this->data['otp'] = '';
    }

    public function switchToEmail(): void
    {
        $this->loginMode = 'email';
        $this->otpSent = false;
    }

    public function sendOtp(): void
    {
        $data = $this->form->getState();
        $rawMobile = $data['mobile_number'] ?? '';

        \Illuminate\Support\Facades\Log::info('Login OTP Attempt Started', [
            'raw_input' => $rawMobile,
            'full_data' => $data
        ]);

        $normalizedMobile = $this->normalizeMobile($rawMobile);

        $user = User::where('mobile_number', $normalizedMobile)->first();

        \Illuminate\Support\Facades\Log::info('Login OTP User Lookup', [
            'normalized' => $normalizedMobile,
            'found' => $user ? 'yes' : 'no',
            'user_id' => $user?->id
        ]);

        if (!$user) {
            Notification::make()
                ->title('User not found')
                ->body("No user found with mobile: $normalizedMobile")
                ->danger()
                ->send();
            return;
        }

        // Generate OTP
        $otp = rand(1000, 9999);
        $expiresAt = Carbon::now()->addMinutes(10);

        $user->update([
            'otp_code' => $otp,
            'otp_expires_at' => $expiresAt,
        ]);

        // Send SMS
        $smsService = app(TaqnyatSmsService::class);
        $sent = $smsService->sendOtp($normalizedMobile, $otp);

        if ($sent) {
            $this->otpSent = true;
            Notification::make()
                ->title('OTP Sent')
                ->body('Please check your phone for the OTP code.')
                ->success()
                ->send();
        } else {
            Notification::make()
                ->title('Failed to send OTP')
                ->body('Please try again later.')
                ->danger()
                ->send();
        }
    }

    public function verifyOtpAndLogin(): ?LoginResponse
    {
        $data = $this->form->getState();
        $rawMobile = $data['mobile_number'] ?? '';
        $otp = $data['otp'] ?? '';
        $normalizedMobile = $this->normalizeMobile($rawMobile);

        $user = User::where('mobile_number', $normalizedMobile)->first();

        if (!$user) {
            throw ValidationException::withMessages([
                'data.mobile_number' => 'User not found.',
            ]);
        }

        if ($user->otp_code !== $otp) {
            throw ValidationException::withMessages([
                'data.otp' => 'Invalid OTP code.',
            ]);
        }

        if (Carbon::now()->greaterThan($user->otp_expires_at)) {
            throw ValidationException::withMessages([
                'data.otp' => 'OTP has expired. Please request a new one.',
            ]);
        }

        // OTP Valid - Clear and login
        $user->update([
            'otp_code' => null,
            'otp_expires_at' => null,
            'last_login_at' => Carbon::now(),
        ]);

        Filament::auth()->login($user, remember: true);

        session()->regenerate();

        return app(LoginResponse::class);
    }

    public function authenticate(): ?LoginResponse
    {
        if ($this->loginMode === 'otp') {
            if (!$this->otpSent) {
                $this->sendOtp();
                return null;
            }
            return $this->verifyOtpAndLogin();
        }

        // Default email/password authentication
        return parent::authenticate();
    }

    protected function normalizeMobile(string $mobile): string
    {
        $digits = preg_replace('/\D/', '', $mobile);

        if (strlen($digits) === 12 && str_starts_with($digits, '966')) {
            return $digits;
        }

        if (strlen($digits) === 10 && str_starts_with($digits, '05')) {
            return '966' . substr($digits, 1);
        }

        if (strlen($digits) === 9 && str_starts_with($digits, '5')) {
            return '966' . $digits;
        }

        return $digits;
    }

    protected function getAuthenticateFormAction(): \Filament\Actions\Action
    {
        $action = parent::getAuthenticateFormAction();

        if ($this->loginMode === 'otp' && !$this->otpSent) {
            return $action->label('Send OTP');
        }

        if ($this->loginMode === 'otp' && $this->otpSent) {
            return $action->label('Verify & Login');
        }

        return $action;
    }

    protected function getFormActions(): array
    {
        return [
            $this->getAuthenticateFormAction(),
        ];
    }

    protected function hasFullWidthFormActions(): bool
    {
        return true;
    }
}
