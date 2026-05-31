<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LandedCost extends Model
{
    use HasFactory;

    protected $fillable = [
        'shipment_id',
        'purchase_order_id',
        'exchange_rate',
        'vat_percentage',
        'shipping_cost_foreign',
        'shipping_cost_sar',
        'customs_cost',
        'broker_cost',
        'total_additional_costs',
        'preparation_status',
        'pricing_status',
        'remarks',
    ];

    protected $casts = [
        'exchange_rate' => 'decimal:4',
        'vat_percentage' => 'decimal:2',
        'shipping_cost_foreign' => 'decimal:2',
        'shipping_cost_sar' => 'decimal:2',
        'customs_cost' => 'decimal:2',
        'broker_cost' => 'decimal:2',
        'total_additional_costs' => 'decimal:2',
    ];

    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }

    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    public function lines(): HasMany
    {
        return $this->hasMany(LandedCostLine::class);
    }

    /**
     * Get the supplier via PO.
     */
    public function getSupplierAttribute()
    {
        return $this->purchaseOrder?->supplier;
    }

    /**
     * Get the currency from the PO's supplier.
     */
    public function getCurrencyAttribute(): string
    {
        return $this->purchaseOrder?->currency ?? $this->purchaseOrder?->supplier?->currency ?? 'SAR';
    }
}
