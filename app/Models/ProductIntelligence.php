<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * The single source of derived inventory intelligence read by every Zooboxi feature.
 * @see \App\Console\Commands\BuildProductIntelligence
 */
class ProductIntelligence extends Model
{
    use HasFactory;

    protected $table = 'product_intelligence';

    protected $guarded = ['id'];

    protected $casts = [
        'ads_30' => 'float',
        'ads_90' => 'float',
        'velocity_blended' => 'float',
        'last_sale_date' => 'date',
        'is_never_sold' => 'bool',
        'current_stock' => 'float',
        'days_of_cover' => 'float',
        'in_stock_rate' => 'float',
        'v_true' => 'float',
        'lost_sales_monthly' => 'float',
        'excess_units' => 'float',
        'unit_cost_sar' => 'float',
        'unit_retail_sar' => 'float',
        'capital_at_risk_sar' => 'float',
        'is_hero' => 'bool',
        'composite_rank_score' => 'float',
        'computed_at' => 'datetime',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class, 'item_code', 'item_code');
    }

    public function scopeItemLevel($query)
    {
        return $query->where('warehouse_code', '');
    }

    public function scopeHealth($query, string $status)
    {
        return $query->where('health_status', $status);
    }
}
