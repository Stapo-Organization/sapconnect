<?php

namespace App\Filament\Resources\ProductAbcClassificationResource\Pages;

use App\Filament\Resources\ProductAbcClassificationResource;
use Filament\Resources\Pages\ListRecords;

class ListProductAbcClassifications extends ListRecords
{
    protected static string $resource = ProductAbcClassificationResource::class;

    protected function getHeaderActions(): array
    {
        return [
            \Filament\Actions\Action::make('what_is_abc')
                ->label(__('📖 ما هو تصنيف ABC؟'))
                ->icon('heroicon-o-question-mark-circle')
                ->color('gray')
                ->modalHeading(__('📖 دليل تصنيف ABC'))
                ->modalDescription(null)
                ->modalContent(view('filament.resources.abc-classification.guide'))
                ->modalSubmitAction(false)
                ->modalCancelActionLabel(__('إغلاق'))
                ->modalWidth('4xl'),
        ];
    }
}
