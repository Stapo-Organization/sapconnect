<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class ZooboxiOrder extends Model
{
    use HasFactory;

    protected $table = 'zooboxi_orders';

    protected $guarded = [];

    protected $casts = [
        'customer_latitude' => 'float',
        'customer_longitude' => 'float',
        'subtotal' => 'float',
        'delivery_fee' => 'float',
        'tax_amount' => 'float',
        'total_amount' => 'float',
        'sap_synced_at' => 'datetime',
        'prepared_at' => 'datetime',
        'woo_status_synced_at' => 'datetime',
    ];

    // ─── Constants ──────────────────────────────────────────────

    const DELIVERY_EXPRESS = 'express';
    const DELIVERY_SAME_DAY = 'same_day';
    const DELIVERY_SHIPPING = 'shipping';
    const DELIVERY_PICKUP = 'pickup';

    const STATUS_PENDING = 'pending';
    const STATUS_PREPARING = 'preparing';
    const STATUS_READY_FOR_PICKUP = 'ready_for_pickup';
    const STATUS_OUT_FOR_DELIVERY = 'out_for_delivery';
    const STATUS_DELIVERED = 'delivered';
    const STATUS_CANCELLED = 'cancelled';

    // ─── Relationships ──────────────────────────────────────────

    /**
     * Get the order lines.
     */
    public function lines()
    {
        return $this->hasMany(ZooboxiOrderLine::class, 'zooboxi_order_id');
    }

    /**
     * Get the assigned warehouse.
     */
    public function zooboxiWarehouse()
    {
        return $this->belongsTo(ZooboxiWarehouse::class, 'warehouse_code', 'warehouse_code');
    }

    /**
     * The branch manager who marked the order prepared.
     */
    public function preparedBy()
    {
        return $this->belongsTo(User::class, 'prepared_by');
    }

    // ─── Scopes ─────────────────────────────────────────────────

    /**
     * Orders pending SAP sync.
     */
    public function scopeUnsyncedToSap(Builder $query): Builder
    {
        return $query->whereNull('sap_synced_at')
            ->where('payment_status', 'paid')
            ->where('delivery_status', '!=', 'cancelled');
    }

    /**
     * Orders by delivery type.
     */
    public function scopeByDeliveryType(Builder $query, string $type): Builder
    {
        return $query->where('delivery_type', $type);
    }

    /**
     * Orders by status.
     */
    public function scopeByStatus(Builder $query, string $status): Builder
    {
        return $query->where('delivery_status', $status);
    }

    /**
     * Orders for a specific warehouse.
     */
    public function scopeForWarehouse(Builder $query, string $warehouseCode): Builder
    {
        return $query->where('warehouse_code', $warehouseCode);
    }

    // ─── Helpers ────────────────────────────────────────────────

    /**
     * Check if the order has been synced to SAP.
     */
    public function isSyncedToSap(): bool
    {
        return $this->sap_synced_at !== null;
    }

    /**
     * Mark the order as synced to SAP.
     */
    public function markSyncedToSap(string $docEntry): void
    {
        $this->update([
            'sap_doc_entry' => $docEntry,
            'sap_synced_at' => now(),
        ]);
    }

    /**
     * Get the delivery type label.
     */
    public function getDeliveryTypeLabelAttribute(): string
    {
        return match ($this->delivery_type) {
            self::DELIVERY_EXPRESS => '🚀 توصيل سريع (ساعتين)',
            self::DELIVERY_SAME_DAY => '📦 توصيل عادي (24 ساعة)',
            self::DELIVERY_SHIPPING => '🚚 شحن (2-4 أيام)',
            self::DELIVERY_PICKUP => '🏬 استلام من الفرع',
            default => $this->delivery_type,
        };
    }

    /**
     * Get the delivery status label.
     */
    public function getDeliveryStatusLabelAttribute(): string
    {
        return match ($this->delivery_status) {
            self::STATUS_PENDING => 'قيد الانتظار',
            self::STATUS_PREPARING => 'قيد التجهيز',
            self::STATUS_READY_FOR_PICKUP => 'جاهز للاستلام',
            self::STATUS_OUT_FOR_DELIVERY => 'في الطريق',
            self::STATUS_DELIVERED => 'تم التوصيل',
            self::STATUS_CANCELLED => 'ملغي',
            default => $this->delivery_status,
        };
    }

    /**
     * Get the total number of items in the order.
     */
    public function getTotalItemsAttribute(): float
    {
        return $this->lines->sum('quantity');
    }
}
