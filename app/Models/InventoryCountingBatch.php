<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One SAP batch (with its expiry) of an item in the count's warehouse, frozen with the book snapshot. */
class InventoryCountingBatch extends Model
{
    protected $fillable = [
        'inventory_counting_id',
        'item_code',
        'batch',
        'expiry_date',
        'quantity',
    ];

    protected $casts = [
        'expiry_date' => 'date',
        'quantity' => 'float',
    ];
}
