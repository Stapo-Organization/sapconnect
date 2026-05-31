<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SuggestedStockTransfer extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_code',
        'source_warehouse',
        'target_warehouse',
        'suggested_quantity',
        'source_ads',
        'source_stock',
        'target_ads',
        'target_stock',
        'status',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function sourceWarehouse()
    {
        return $this->belongsTo(Warehouse::class, 'source_warehouse', 'warehouse_code');
    }

    public function targetWarehouse()
    {
        return $this->belongsTo(Warehouse::class, 'target_warehouse', 'warehouse_code');
    }
}
