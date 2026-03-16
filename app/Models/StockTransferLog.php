<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StockTransferLog extends Model
{
    protected $table = 'stock_transfer_logs';

    protected $fillable = [
        'stock_transfer_id',
        'user_id',
        'action',
        'from_status',
        'to_status',
        'payload',
        'ip_address',
    ];

    protected $casts = [
        'payload' => 'array',
    ];

    // Action Constants
    const ACTION_IMPORTED = 'imported';
    const ACTION_ITEMS_SENT = 'items_sent';
    const ACTION_SEND_CONFIRMED = 'send_confirmed';
    const ACTION_ITEMS_RECEIVED = 'items_received';
    const ACTION_RECEIVE_CONFIRMED = 'receive_confirmed';

    public function transfer()
    {
        return $this->belongsTo(StockTransfer::class, 'stock_transfer_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Create a log entry for a stock transfer action.
     */
    public static function record(
        int $stockTransferId,
        int $userId,
        string $action,
        ?string $fromStatus = null,
        ?string $toStatus = null,
        ?array $payload = null,
        ?string $ipAddress = null
    ): self {
        return self::create([
            'stock_transfer_id' => $stockTransferId,
            'user_id' => $userId,
            'action' => $action,
            'from_status' => $fromStatus,
            'to_status' => $toStatus,
            'payload' => $payload,
            'ip_address' => $ipAddress,
        ]);
    }
}
