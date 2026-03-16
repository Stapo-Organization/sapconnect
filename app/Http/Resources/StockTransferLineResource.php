<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockTransferLineResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'line_id' => $this->id,
            'item_code' => $this->item_code,
            'item_description' => $this->item_description,
            'quantity' => (float) $this->quantity, // Original Qty
            'sent_quantity' => (float) $this->sent_quantity, // Actual Sent
            'received_quantity' => (float) $this->received_quantity, // (Maybe rename to actual_received to be clear, but staying consistent with DB column if it differs) 
            'actual_received_quantity' => (float) $this->actual_received_quantity, // Explicit field from casts
            'remaining_quantity' => (float) $this->sent_quantity - (float) $this->actual_received_quantity,
            'receiving_percentage' => $this->sent_quantity > 0 ? round(((float) $this->actual_received_quantity / (float) $this->sent_quantity) * 100, 2) : 0,
            'line_status' => $this->line_status,
        ];
    }
}
