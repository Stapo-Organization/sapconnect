<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InventoryCountingApiResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // 'lines' is only present when eager-loaded; whenLoaded() returns a
        // MissingValue (a truthy object with no collection methods) otherwise,
        // so guard on relationLoaded() before treating it as a collection.
        $linesCount = 0;
        $totalCountedQty = 0;

        if ($this->relationLoaded('lines')) {
            $linesCount = $this->lines->count();
            $totalCountedQty = $this->lines->sum('counted_quantity');
        }

        return [
            'id' => $this->id,
            'warehouse_code' => $this->warehouse_code,
            'warehouse_name' => $this->warehouse_name,
            'status' => $this->status,
            'counting_type' => $this->counting_type ?? 'full',
            'priority' => $this->priority ?? 'medium',
            'scheduled_date' => $this->scheduled_date,
            'total_target_items' => $this->total_target_items ?? 0,
            'cycle_plan_id' => $this->cycle_plan_id,
            'plan_name' => $this->whenLoaded('cyclePlan', fn() => $this->cyclePlan?->plan_name),
            'started_by' => $this->started_by,
            'counted_by' => $this->whenLoaded('user', fn() => [
                'id' => $this->user?->id,
                'name' => $this->user?->name,
            ]),
            'notes' => $this->notes,
            'lines_count' => $linesCount ?: $this->lines()->count(),
            'total_counted_qty' => $totalCountedQty,
            'created_at' => $this->created_at,
            'completed_at' => $this->completed_at,
            'lines' => InventoryCountingLineApiResource::collection($this->whenLoaded('lines')),
        ];
    }
}
