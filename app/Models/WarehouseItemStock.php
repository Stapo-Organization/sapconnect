<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WarehouseItemStock extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_code',
        'warehouse_code',
        'in_stock',
        'committed',
        'ordered',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class, 'warehouse_code', 'warehouse_code');
    }
}
