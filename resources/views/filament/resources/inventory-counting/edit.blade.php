<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Form --}}
        <x-filament-panels::form wire:submit="save">
            {{ $this->form }}
        </x-filament-panels::form>

        {{-- Barcode Scanner --}}
        @livewire(\App\Livewire\InventoryScanner::class, ['countingId' => $record->id, 'isReadOnly' => false])

        {{-- Save Button --}}
        <div class="flex justify-end">
            <x-filament::button wire:click="save" size="lg">
                {{ __('Save') }}
            </x-filament::button>
        </div>
    </div>
</x-filament-panels::page>
