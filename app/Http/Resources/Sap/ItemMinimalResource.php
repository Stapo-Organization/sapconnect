<?php

namespace App\Http\Resources\Sap;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ItemMinimalResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        // Check if we have the specific fields requested
        // SAP Service Layer uses PascalCase

        return [
            'ItemCode' => $this['ItemCode'] ?? null,
            'ItemName' => $this['ItemName'] ?? null,
            // Filter ItemPrices if present
            'ItemPrices' => isset($this['ItemPrices'])
                ? collect($this['ItemPrices'])->map(function ($price) {
                    return [
                        'PriceList' => $price['PriceList'] ?? null,
                        'Price' => $price['Price'] ?? null,
                        // We can add Currency or others if needed, but user asked for specific subset
                    ];
                })->toArray()
                : [],
            // Include other fields? Or Strict mode? 
            // The user said "I need to get Items like this", implying a strict subset.
            // But usually APIs provide more. I'll stick to the requested + minimal extras if needed.
            // For now, EXACT match to request.
        ];
    }
}
