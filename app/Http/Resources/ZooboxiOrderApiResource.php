<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Express Zooboxi order as seen by the branch manager app.
 */
class ZooboxiOrderApiResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'woo_order_id' => $this->woo_order_id,
            'woo_order_number' => $this->woo_order_number,
            'warehouse_code' => $this->warehouse_code,
            'delivery_type' => $this->delivery_type,
            'delivery_type_label' => $this->delivery_type_label,
            'delivery_status' => $this->delivery_status,
            'delivery_status_label' => $this->delivery_status_label,
            'customer' => [
                'name' => $this->customer_name,
                'phone' => $this->customer_phone,
                'city' => $this->customer_city,
                'address' => $this->customer_address,
            ],
            'totals' => [
                'subtotal' => $this->subtotal,
                'delivery_fee' => $this->delivery_fee,
                'tax_amount' => $this->tax_amount,
                'total_amount' => $this->total_amount,
            ],
            'payment_method' => $this->payment_method,
            'payment_status' => $this->payment_status,
            'total_items' => $this->whenLoaded('lines', fn() => (float) $this->lines->sum('quantity')),
            'minutes_since_created' => $this->created_at?->diffInMinutes(now()),
            'created_at' => $this->created_at,
            'prepared_at' => $this->prepared_at,
            'lines' => $this->whenLoaded('lines', fn() => $this->lines->map(fn($line) => [
                'id' => $line->id,
                'item_code' => $line->item_code,
                'item_name' => $line->item_name,
                'quantity' => (float) $line->quantity,
                'unit_price' => (float) $line->unit_price,
                'total_price' => (float) $line->total_price,
            ])->values()),
        ];
    }
}
