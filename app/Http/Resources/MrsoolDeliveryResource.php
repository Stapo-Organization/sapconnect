<?php

namespace App\Http\Resources;

use App\Models\MrsoolDelivery;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One Mrsool (مرسول) courier request as the branch-manager app sees it.
 *
 * @mixin \App\Models\MrsoolDelivery
 */
class MrsoolDeliveryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'              => $this->id,
            'mrsool_order_id' => $this->mrsool_order_id,
            'status'          => $this->status,
            'status_label'    => MrsoolDelivery::labelFor($this->status),
            'phase'           => $this->phase,
            'is_partial'      => (bool) $this->is_partial,
            'price_quote'     => $this->price_quote !== null ? (float) $this->price_quote : null,
            'courier' => [
                'name'  => $this->courier_name,
                'phone' => $this->courier_phone,
                'lat'   => $this->courier_lat !== null ? (float) $this->courier_lat : null,
                'lng'   => $this->courier_lng !== null ? (float) $this->courier_lng : null,
            ],
            'events' => collect($this->events ?? [])->map(fn ($e) => [
                'event' => $e['event'] ?? null,
                'label' => MrsoolDelivery::labelFor($e['event'] ?? null),
                'at'    => $e['created_at'] ?? null,
            ])->values(),
            'pickup_images'  => array_values($this->pickup_images ?? []),
            'dropoff_images' => array_values($this->dropoff_images ?? []),
            'awb_url'        => $this->awb_url,
            'last_error'     => $this->last_error,
            'requested_at'   => $this->requested_at,
            'assigned_at'    => $this->assigned_at,
            'picked_up_at'   => $this->picked_up_at,
            'delivered_at'   => $this->delivered_at,
            'failed_at'      => $this->failed_at,
            'last_synced_at' => $this->last_synced_at,
            'can_cancel'     => $this->canCancel(),
        ];
    }
}
