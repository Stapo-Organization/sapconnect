<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class StockTransfer extends Model
{
    use HasFactory;

    protected $table = 'sap_stock_transfers';
    protected $guarded = [];

    // Internal Statuses (workflow)
    const STATUS_NEW = 'New';
    const STATUS_SHIPPED = 'Shipped';
    const STATUS_PARTIALLY_RECEIVED = 'Partially Received';
    const STATUS_RECEIVED = 'Received';
    const STATUS_COMPLETED = 'Completed';

    protected $casts = [
        'doc_date' => 'date',
        'creation_date' => 'datetime',
        'update_date' => 'datetime',
        'sent_at' => 'datetime',
        'received_at' => 'datetime',
    ];

    // ─── Relationships ──────────────────────────────────────────

    public function lines()
    {
        return $this->hasMany(StockTransferLine::class, 'stock_transfer_id');
    }

    public function fromWarehouse()
    {
        return $this->belongsTo(Warehouse::class, 'from_warehouse', 'warehouse_code');
    }

    public function toWarehouse()
    {
        return $this->belongsTo(Warehouse::class, 'to_warehouse', 'warehouse_code');
    }

    public function shipments()
    {
        return $this->hasMany(StockTransferShipment::class, 'stock_transfer_id');
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sent_by');
    }

    public function receiver()
    {
        return $this->belongsTo(User::class, 'received_by');
    }

    public function logs()
    {
        return $this->hasMany(StockTransferLog::class, 'stock_transfer_id')->latest();
    }

    // ─── Scopes ─────────────────────────────────────────────────

    public function scopeForDatabase(Builder $query, string $db): Builder
    {
        return $query->where('sap_database', $db);
    }

    public function scopeForWarehouse(Builder $query, array $codes): Builder
    {
        return $query->where(function ($q) use ($codes) {
            $q->whereIn('from_warehouse', $codes)
                ->orWhereIn('to_warehouse', $codes);
        });
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Check if this transfer can be sent (by the sender warehouse user).
     */
    public function canSend(): bool
    {
        return $this->internal_status === self::STATUS_NEW;
    }

    /**
     * Check if this transfer can be received (by the receiver warehouse user).
     */
    public function canReceive(): bool
    {
        return $this->internal_status === self::STATUS_SHIPPED;
    }

    /**
     * Check if the given warehouse codes are related to this transfer.
     */
    public function isForWarehouse(array $codes): bool
    {
        return in_array($this->from_warehouse, $codes) || in_array($this->to_warehouse, $codes);
    }

    /**
     * Check if the given warehouse codes belong to the sender side.
     */
    public function isSenderWarehouse(array $codes): bool
    {
        return in_array($this->from_warehouse, $codes);
    }

    /**
     * Check if the given warehouse codes belong to the receiver side.
     */
    public function isReceiverWarehouse(array $codes): bool
    {
        return in_array($this->to_warehouse, $codes);
    }
}
