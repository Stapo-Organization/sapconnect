<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductBundleItem extends Model
{
    protected $fillable = [
        'product_bundle_id', 'item_code', 'item_name', 'barcode',
        'qty', 'role', 'unit_retail', 'unit_cost',
    ];

    protected $casts = [
        'qty' => 'integer',
        'unit_retail' => 'float',
        'unit_cost' => 'float',
    ];

    public function bundle(): BelongsTo
    {
        return $this->belongsTo(ProductBundle::class, 'product_bundle_id');
    }
}
