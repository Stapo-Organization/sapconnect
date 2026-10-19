<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** SAP InStock for one item, frozen when a full count starts (the book quantity). */
class InventoryCountingSnapshot extends Model
{
    protected $fillable = [
        'inventory_counting_id',
        'item_code',
        'system_qty',
        'unit_cost',
        'sap_unit_cost',
    ];

    protected $casts = [
        'system_qty' => 'float',
        'unit_cost' => 'float',
        'sap_unit_cost' => 'float',
    ];
}
