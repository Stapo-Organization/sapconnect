<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ZooboxiOrderLine extends Model
{
    use HasFactory;

    protected $table = 'zooboxi_order_lines';

    protected $fillable = [
        'zooboxi_order_id',
        'item_code',
        'item_name',
        'warehouse_code',
        'quantity',
        'unit_price',
        'total_price',
    ];

    protected $casts = [
        'quantity' => 'float',
        'unit_price' => 'float',
        'total_price' => 'float',
    ];

    // ─── Relationships ──────────────────────────────────────────

    /**
     * Get the parent order.
     */
    public function order()
    {
        return $this->belongsTo(ZooboxiOrder::class, 'zooboxi_order_id');
    }

    /**
     * Get the product.
     */
    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    /**
     * Get the warehouse stock record.
     */
    public function warehouseStock()
    {
        return $this->belongsTo(WarehouseItemStock::class, 'item_code', 'item_code')
            ->where('warehouse_code', $this->warehouse_code);
    }
}
