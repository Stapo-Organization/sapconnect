<?php

namespace App\Http\Resources;

use App\Services\Mrsool\MrsoolDeliveryService;
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
                // Needed by the app's courier map.
                'latitude' => $this->customer_latitude !== null ? (float) $this->customer_latitude : null,
                'longitude' => $this->customer_longitude !== null ? (float) $this->customer_longitude : null,
            ],
            'warehouse' => $this->warehouseBlock(),
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
            'mrsool' => $this->mrsoolBlock(),
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

    /**
     * Pickup point for the courier map (null when the order has no branch).
     */
    private function warehouseBlock(): ?array
    {
        $warehouse = $this->zooboxiWarehouse;
        if (!$warehouse) {
            return null;
        }

        return [
            'code' => $warehouse->warehouse_code,
            'name' => $warehouse->display_name_ar ?: $warehouse->warehouse_code,
            'latitude' => $warehouse->latitude !== null ? (float) $warehouse->latitude : null,
            'longitude' => $warehouse->longitude !== null ? (float) $warehouse->longitude : null,
        ];
    }

    /**
     * Mrsool (مرسول) summary. `eligible` is the CHEAP gate only (switch, express,
     * pilot branch, not COD, coords present) — the daily cap and the API live in
     * GET /zooboxi-orders/{id}/mrsool, so a list render costs no extra calls.
     */
    private function mrsoolBlock(): array
    {
        /** @var MrsoolDeliveryService $service */
        $service = app(MrsoolDeliveryService::class);
        $active = $this->activeMrsoolDelivery;

        return [
            'eligible' => $service->eligibleQuick($this->resource),
            'active' => $active ? new MrsoolDeliveryResource($active) : null,
        ];
    }
}
