<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_code',
        'item_name',
        'foreign_name',
        'items_group_code',
        'inventory_uom',
        'piece_barcode',
        'sales_items_per_unit',
        'create_date',
        'update_date',
        'source',
        'prices',
    ];

    protected $casts = [
        'prices' => 'array',
    ];


    public function scopeProduction($query)
    {
        return $query->where('source', 'production');
    }
}
