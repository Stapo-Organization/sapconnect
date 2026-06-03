<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockTransferResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $lines = $this->whenLoaded('lines');
        $images = [];
        $totalQty = 0;
        $totalSent = 0;
        $totalReceived = 0;
        $sapReceivedQty = 0;

        if ($lines && $lines->isNotEmpty()) {
            $totalQty = $lines->sum('quantity');
            $totalSent = $lines->sum('sent_quantity');
            $totalReceived = $lines->sum('actual_received_quantity');
            $sapReceivedQty = $lines->sum('received_quantity');

            $images = $lines->map(fn($line) => $line->product)
                ->filter()
                ->unique('item_code')
                ->take(5)
                ->map(function ($product) {
                    $code = $product->item_code;
                    $folder = substr($code, 0, 4);
                    return "https://ppte.sa/img/{$folder}/{$code}.png";
                })
                ->values();
        }

        $sendingPercentage = $totalQty > 0 ? round(($totalSent / $totalQty) * 100, 2) : 0;
        $receivingPercentage = $totalSent > 0 ? round(($totalReceived / $totalSent) * 100, 2) : 0;
        $sapReceivedPercentage = $totalQty > 0 ? round(($sapReceivedQty / $totalQty) * 100, 2) : 0;

        // Direction relative to the requesting user (for Send / Receive tabs).
        // Admins (no warehouse restriction) appear in both directions.
        $userCodes = [];
        $reqUser = $request->user();
        if ($reqUser && $reqUser->warehouse_code) {
            $wc = $reqUser->warehouse_code;
            if (is_string($wc)) {
                $decoded = json_decode($wc, true);
                $wc = (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) ? $decoded : [$wc];
            }
            $userCodes = is_array($wc) ? $wc : [$wc];
        }
        $isOutgoing = empty($userCodes) ? true : in_array($this->from_warehouse, $userCodes);
        $isIncoming = empty($userCodes) ? true : in_array($this->to_warehouse, $userCodes);

        return [
            'id' => $this->id,
            'doc_entry' => $this->doc_entry,
            'doc_num' => $this->doc_num,
            'from_warehouse' => $this->from_warehouse,
            'to_warehouse' => $this->to_warehouse,
            'doc_date' => $this->doc_date?->format('Y-m-d'),
            'creation_date' => $this->creation_date,

            // Quantities
            'total_qty' => $totalQty,
            'sap_sent_qty' => $totalQty,
            'sap_received_qty' => $sapReceivedQty,
            'sap_received_percentage' => $sapReceivedPercentage,
            'total_sent_qty' => $totalSent,
            'total_received_qty' => $totalReceived,
            'sending_percentage' => $sendingPercentage,
            'receiving_percentage' => $receivingPercentage,

            // Status
            'document_status' => $this->document_status,
            'internal_status' => $this->internal_status ?? 'New',

            // Workflow tracking
            'sent_by' => $this->whenLoaded('sender', fn() => [
                'id' => $this->sender?->id,
                'name' => $this->sender?->name,
            ]),
            'sent_at' => $this->sent_at,
            'received_by' => $this->whenLoaded('receiver', fn() => [
                'id' => $this->receiver?->id,
                'name' => $this->receiver?->name,
            ]),
            'received_at' => $this->received_at,
            'sender_notes' => $this->sender_notes,
            'receiver_notes' => $this->receiver_notes,

            // Permissions (for current user)
            'can_send' => $this->resource->canSend(),
            'can_receive' => $this->resource->canReceive(),

            // Direction relative to the requesting user (Send / Receive tabs)
            'is_outgoing' => $isOutgoing,
            'is_incoming' => $isIncoming,

            // Media
            'images' => $images,

            // Lines
            'lines' => StockTransferLineResource::collection($this->whenLoaded('lines')),
            'logs_count' => $this->logs_count ?? $this->logs()->count(),
        ];
    }
}
