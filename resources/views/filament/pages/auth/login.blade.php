<x-filament-panels::page.simple>
    {{-- Tabs for switching login mode --}}
    <div class="mb-6">
        <div class="flex rounded-lg bg-gray-100 dark:bg-gray-800 p-1">
            <button type="button" wire:click="switchToEmail" class="flex-1 py-2 px-4 text-sm font-medium rounded-md transition-colors duration-200
                    {{ $this->loginMode === 'email'
    ? 'bg-white dark:bg-gray-700 text-primary-600 shadow-sm'
    : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300' }}">
                Email Login
            </button>
            <button type="button" wire:click="switchToOtp" class="flex-1 py-2 px-4 text-sm font-medium rounded-md transition-colors duration-200
                    {{ $this->loginMode === 'otp'
    ? 'bg-white dark:bg-gray-700 text-primary-600 shadow-sm'
    : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300' }}">
                Mobile OTP
            </button>
        </div>
    </div>

    <x-filament-panels::form wire:submit="authenticate">
        {{ $this->form }}

        <x-filament-panels::form.actions :actions="$this->getCachedFormActions()"
            :full-width="$this->hasFullWidthFormActions()" />
    </x-filament-panels::form>
</x-filament-panels::page.simple>