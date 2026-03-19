<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ShipmentContainer extends Model
{
    use HasFactory;

    protected $fillable = [
        'shipment_id',
        'container_type',
        'container_number',
        'pallet_count',
        'freight_cost'
    ];

    /**
     * Get the shipment that owns the container.
     */
    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }
}
