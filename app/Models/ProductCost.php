<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * The single source of truth for an item's unit cost (margin/clearance floors).
 * @see \App\Console\Commands\SeedProductCosts
 */
class ProductCost extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_code',
        'cost_proxy_sar',
        'cost_confidence',
        'source',
        'brand_median_margin',
        'computed_at',
    ];

    protected $casts = [
        'cost_proxy_sar' => 'float',
        'brand_median_margin' => 'float',
        'computed_at' => 'datetime',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function scopeActual($query)
    {
        return $query->where('cost_confidence', 'actual');
    }
}
