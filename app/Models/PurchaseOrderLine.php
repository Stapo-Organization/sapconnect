<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PurchaseOrderLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'purchase_order_id',
        'sap_line_num',
        'item_code',
        'product_id',
        'description',
        'item_description',
        'quantity',
        'unit_price',
        'total_price',
        'pallet_quantity',
        'warehouse_code',
        'uom',
    ];

    /**
     * Get the parent purchase order.
     */
    public function purchaseOrder(): BelongsTo
    {
        return $this->belongsTo(PurchaseOrder::class);
    }

    /**
     * Get the product for the line.
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
