<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ShipmentLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'shipment_id',
        'purchase_order_line_id',
        'shipped_quantity',
        'notes',
    ];

    /**
     * Get the parent shipment.
     */
    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }

    /**
     * Get the referenced purchase order line item.
     */
    public function purchaseOrderLine(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrderLine::class);
    }
}
