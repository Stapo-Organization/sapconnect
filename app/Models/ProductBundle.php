<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductBundle extends Model
{
    public const STATUS_SUGGESTED = 'suggested';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_LIVE = 'live';
    public const STATUS_RETIRED = 'retired';
    public const STATUS_REJECTED = 'rejected';

    public const TEMPLATES = ['stacking', 'variety', 'companion', 'smart_gift', 'seasonal'];

    protected $fillable = [
        'bundle_key', 'template', 'status',
        'name_ar', 'subtitle_ar', 'free_label',
        'anchor_item_code', 'species', 'kind',
        'sum_retail', 'bundle_price', 'sum_cost', 'floor_price', 'savings_pct',
        'stock_class', 'warehouse_scope',
        'score', 'rationale',
        'wc_product_id', 'image_url',
        'approved_by', 'approved_at', 'rejected_reason', 'retired_at', 'computed_at',
    ];

    protected $casts = [
        'warehouse_scope' => 'array',
        'rationale' => 'array',
        'sum_retail' => 'float',
        'bundle_price' => 'float',
        'sum_cost' => 'float',
        'floor_price' => 'float',
        'savings_pct' => 'float',
        'score' => 'float',
        'approved_at' => 'datetime',
        'retired_at' => 'datetime',
        'computed_at' => 'datetime',
    ];

    public function items(): HasMany
    {
        return $this->hasMany(ProductBundleItem::class)->orderByDesc('role');
    }
}
