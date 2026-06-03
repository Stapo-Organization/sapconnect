<?php

namespace App\Filament\Resources\QualityTaskInstanceResource\Pages;

use App\Filament\Resources\QualityTaskInstanceResource;
use Filament\Resources\Pages\ViewRecord;

class ViewQualityTaskInstance extends ViewRecord
{
    protected static string $resource = QualityTaskInstanceResource::class;

    protected static string $view = 'filament.resources.quality-task-instance.view';
}
