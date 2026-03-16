<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockTransferLogResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'action' => $this->action,
            'action_label' => $this->getActionLabel(),
            'from_status' => $this->from_status,
            'to_status' => $this->to_status,
            'payload' => $this->payload,
            'user' => [
                'id' => $this->user?->id,
                'name' => $this->user?->name,
            ],
            'ip_address' => $this->ip_address,
            'created_at' => $this->created_at,
        ];
    }

    protected function getActionLabel(): string
    {
        return match ($this->action) {
            'imported' => 'تم الاستيراد من SAP',
            'items_sent' => 'تم تحديث الكميات المرسلة',
            'send_confirmed' => 'تم تأكيد الإرسال',
            'items_received' => 'تم تحديث الكميات المستلمة',
            'receive_confirmed' => 'تم تأكيد الاستلام',
            default => $this->action,
        };
    }
}
