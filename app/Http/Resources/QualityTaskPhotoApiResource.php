<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class QualityTaskPhotoApiResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'url' => $this->url,
            'checklist_item_key' => $this->checklist_item_key,
            'original_name' => $this->original_name,
            'size' => $this->size,
        ];
    }
}
