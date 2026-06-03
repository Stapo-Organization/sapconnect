<?php

namespace App\Filament\Resources\InventoryCyclePlanResource\Pages;

use App\Filament\Resources\InventoryCyclePlanResource;
use Filament\Resources\Pages\ListRecords;

class ListInventoryCyclePlans extends ListRecords
{
    protected static string $resource = InventoryCyclePlanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            \Filament\Actions\Action::make('how_it_works')
                ->label(__('📖 كيف يعمل الجرد الدوري؟'))
                ->icon('heroicon-o-question-mark-circle')
                ->color('gray')
                ->modalHeading(__('📖 دليل خطط الجرد الدوري'))
                ->modalDescription(null)
                ->modalContent(view('filament.resources.cycle-plan.guide'))
                ->modalSubmitAction(false)
                ->modalCancelActionLabel(__('إغلاق'))
                ->modalWidth('4xl'),

            \Filament\Actions\CreateAction::make(),
        ];
    }
}
