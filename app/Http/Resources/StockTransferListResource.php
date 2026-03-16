<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockTransferListResource extends StockTransferResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // Get the parent array (which includes all logic for totals, status etc)
        $data = parent::toArray($request);

        // Remove the heavy lines array
        unset($data['lines']);

        // Add the lines count
        // Note: Using $this->lines relies on the relationship being loaded or available 
        // on the model $this->resource. Since parent::toArray used it for totals, it is available.
        $data['lines_count'] = $this->lines->count();

        return $data;
    }
}
