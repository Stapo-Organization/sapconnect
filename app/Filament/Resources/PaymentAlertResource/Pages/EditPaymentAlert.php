<?php

namespace App\Filament\Resources\PaymentAlertResource\Pages;

use App\Filament\Resources\PaymentAlertResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditPaymentAlert extends EditRecord
{
    protected static string $resource = PaymentAlertResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
