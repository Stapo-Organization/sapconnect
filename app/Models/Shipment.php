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
        'forwarder_id',
        'broker_id',
        'transport_mode',
        'shipment_terms',
        'origin_port',
        'country_of_origin',
        'storage_location_id',
        'mbl',
        'hbl',
        'etd',
        'eta',
        'received_date',
        'total_freight_cost',
        'freight_invoice_no',
        'freight_invoice_amount',
        'customs_manifest_no',
        'clearance_invoice_no',
        'clearance_amount',
        'exchange_rate',
        'order_description',
        'remarks',
        'notes',
    ];

    protected $casts = [
        'etd' => 'date',
        'eta' => 'date',
        'received_date' => 'date',
        'is_announced' => 'boolean',
        'exchange_rate' => 'decimal:4',
        'freight_invoice_amount' => 'decimal:2',
        'clearance_amount' => 'decimal:2',
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

    /**
     * Get the line items for the shipment (partial shipment tracking).
     */
    public function shipmentLines(): HasMany
    {
        return $this->hasMany(ShipmentLine::class);
    }

    /**
     * Get the payment alerts triggered by this shipment.
     */
    public function paymentAlerts(): HasMany
    {
        return $this->hasMany(PaymentAlert::class);
    }

    /**
     * Get the forwarder handling this shipment.
     */
    public function forwarder(): BelongsTo
    {
        return $this->belongsTo(Forwarder::class);
    }

    /**
     * Get the customs clearance broker.
     */
    public function broker(): BelongsTo
    {
        return $this->belongsTo(Broker::class);
    }

    /**
     * Calculate days until arrival (computed attribute).
     */
    public function getDaysUntilArrivalAttribute(): ?int
    {
        if (!$this->eta) return null;
        return (int) now()->diffInDays($this->eta, false);
    }
}
