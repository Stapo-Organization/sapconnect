<?php

namespace App\Filament\Resources\PaymentPolicyResource\Pages;

use App\Filament\Resources\PaymentPolicyResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditPaymentPolicy extends EditRecord
{
    protected static string $resource = PaymentPolicyResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
