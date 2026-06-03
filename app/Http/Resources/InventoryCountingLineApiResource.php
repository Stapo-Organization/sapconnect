<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InventoryCountingLineApiResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'item_code' => $this->item_code,
            'item_name' => $this->item_name,
            'item_name_ar' => $this->product ? ($this->product->foreign_name ?: ($this->product->zb_name_ar ?: $this->item_name)) : $this->item_name,
            'item_name_en' => $this->product ? ($this->product->item_name ?: ($this->product->zb_name_en ?: $this->item_name)) : $this->item_name,
            'piece_barcode' => $this->piece_barcode,
            'counted_quantity' => (float) $this->counted_quantity,
            'system_quantity' => (float) $this->system_quantity,
            'variance' => (float) $this->variance,
            'variance_percentage' => (float) $this->variance_percentage,
            'variance_status' => $this->variance_status,
            'investigation_note' => $this->investigation_note,
            'image_url' => $this->image_url,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
