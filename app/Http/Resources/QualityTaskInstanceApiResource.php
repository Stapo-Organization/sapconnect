<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class QualityTaskInstanceApiResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $snap = $this->requirements_snapshot ?? [];
        $slot = $snap['slot'] ?? null;
        $slotKey = $this->slot_key;
        $hasSlot = $slot && ($slot['key'] ?? '_default') !== '_default';

        return [
            'id' => $this->id,
            'quality_task_id' => $this->quality_task_id,
            'warehouse_code' => $this->warehouse_code,
            'warehouse_name' => $this->warehouse_name,
            'title' => $this->title,
            'description' => $this->description,
            'status' => $this->status,
            'scheduled_date' => $this->scheduled_date?->toDateString(),
            'slot_key' => $slotKey === '_default' ? null : $slotKey,
            'slot_label_ar' => $hasSlot ? ($slot['label_ar'] ?? null) : null,
            'slot_label_en' => $hasSlot ? ($slot['label_en'] ?? null) : null,
            'priority' => $this->priority,
            'is_overdue' => $this->isOverdue(),

            'requirements' => [
                'proof_type' => $snap['proof_type'] ?? 'photo',
                'min_photos' => (int) ($snap['min_photos'] ?? 1),
                'require_comment' => (bool) ($snap['require_comment'] ?? false),
                'checklist_items' => $snap['checklist_items'] ?? [],
            ],

            'comment' => $this->comment,
            'checklist_results' => $this->checklist_results ?? [],
            'photos' => QualityTaskPhotoApiResource::collection($this->whenLoaded('photos')),
            'photos_count' => $this->whenLoaded('photos', fn () => $this->photos->count(), 0),

            'submitted_by' => $this->submitted_by,
            'submitted_at' => $this->submitted_at,
            'created_at' => $this->created_at,
        ];
    }
}
