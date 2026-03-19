<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Shipment extends Model
{
    use HasFactory;

    protected $fillable = [
        'purchase_order_id',
        'status',
        'is_announced',
        'forwarder_name',
        'transport_mode',
        'origin_port',
        'storage_location_id',
        'mbl',
        'hbl',
        'etd',
        'eta',
        'total_freight_cost'
    ];

    protected $casts = [
        'etd' => 'date',
        'eta' => 'date',
        'is_announced' => 'boolean',
    ];

    /**
     * Get the parent purchase order.
     */
    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    /**
     * Get the storage location (Warehouse).
     */
    public function storageLocation(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class, 'storage_location_id');
    }

    /**
     * Get the containers for the shipment.
     */
    public function containers(): HasMany
    {
        return $this->hasMany(ShipmentContainer::class);
    }
}
